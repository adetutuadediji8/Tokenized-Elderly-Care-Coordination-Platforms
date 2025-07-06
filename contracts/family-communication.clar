;; Family Communication Contract
;; Facilitates updates between family members and caregivers

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_DATA (err u402))
(define-constant ERR_ALREADY_EXISTS (err u403))
(define-constant ERR_PERMISSION_DENIED (err u404))

;; Data Variables
(define-data-var next-message-id uint u1)
(define-data-var next-update-id uint u1)

;; Data Maps
(define-map family-members
  { senior-id: uint, member-address: principal }
  {
    name: (string-ascii 100),
    relationship: (string-ascii 50),
    permission-level: (string-ascii 20),
    verified: bool,
    added-at: uint,
    last-active: uint
  }
)

(define-map family-care-updates
  { update-id: uint }
  {
    senior-id: uint,
    update-type: (string-ascii 50),
    title: (string-ascii 100),
    content: (string-ascii 1000),
    priority: (string-ascii 20),
    posted-by: principal,
    posted-at: uint,
    visibility: (string-ascii 20)
  }
)

(define-map communication-messages
  { message-id: uint }
  {
    senior-id: uint,
    sender: principal,
    recipient: principal,
    subject: (string-ascii 100),
    message: (string-ascii 500),
    sent-at: uint,
    read: bool,
    read-at: (optional uint)
  }
)

(define-map notification-preferences
  { senior-id: uint, member-address: principal }
  {
    health-updates: bool,
    care-updates: bool,
    emergency-alerts: bool,
    daily-reports: bool,
    medication-reminders: bool,
    appointment-notifications: bool
  }
)

(define-map communication-permissions
  { senior-id: uint }
  {
    allow-family-updates: bool,
    allow-caregiver-messages: bool,
    require-approval: bool,
    privacy-level: (string-ascii 20)
  }
)

(define-map daily-reports
  { senior-id: uint, report-date: uint }
  {
    activities-completed: (string-ascii 300),
    health-status: (string-ascii 200),
    mood-assessment: (string-ascii 100),
    medications-taken: (string-ascii 200),
    concerns: (string-ascii 300),
    reported-by: principal,
    report-time: uint
  }
)

;; Read-only functions
(define-read-only (get-family-member (senior-id uint) (member-address principal))
  (map-get? family-members { senior-id: senior-id, member-address: member-address })
)

(define-read-only (get-care-update (update-id uint))
  (map-get? family-care-updates { update-id: update-id })
)

(define-read-only (get-communication-message (message-id uint))
  (map-get? communication-messages { message-id: message-id })
)

(define-read-only (get-notification-preferences (senior-id uint) (member-address principal))
  (map-get? notification-preferences { senior-id: senior-id, member-address: member-address })
)

(define-read-only (get-communication-permissions (senior-id uint))
  (map-get? communication-permissions { senior-id: senior-id })
)

(define-read-only (get-daily-report (senior-id uint) (report-date uint))
  (map-get? daily-reports { senior-id: senior-id, report-date: report-date })
)

(define-read-only (get-next-message-id)
  (var-get next-message-id)
)

(define-read-only (get-next-update-id)
  (var-get next-update-id)
)

(define-read-only (is-authorized-family-member (senior-id uint) (member-address principal))
  (is-some (get-family-member senior-id member-address))
)

;; Public functions
(define-public (add-family-member
  (senior-id uint)
  (member-address principal)
  (name (string-ascii 100))
  (relationship (string-ascii 50))
  (permission-level (string-ascii 20))
)
  (begin
    (asserts! (not (is-some (get-family-member senior-id member-address))) ERR_ALREADY_EXISTS)
    (asserts! (or
      (is-eq permission-level "view")
      (is-eq permission-level "update")
      (is-eq permission-level "admin")
    ) ERR_INVALID_DATA)

    (map-set family-members
      { senior-id: senior-id, member-address: member-address }
      {
        name: name,
        relationship: relationship,
        permission-level: permission-level,
        verified: false,
        added-at: block-height,
        last-active: block-height
      }
    )
    (ok true)
  )
)

(define-public (verify-family-member (senior-id uint))
  (let ((member (get-family-member senior-id tx-sender)))
    (asserts! (is-some member) ERR_NOT_FOUND)

    (map-set family-members
      { senior-id: senior-id, member-address: tx-sender }
      (merge (unwrap-panic member) { verified: true })
    )
    (ok true)
  )
)

(define-public (set-notification-preferences
  (senior-id uint)
  (preferences-data {
    health-updates: bool,
    care-updates: bool,
    emergency-alerts: bool,
    daily-reports: bool,
    medication-reminders: bool,
    appointment-notifications: bool
  })
)
  (begin
    (asserts! (is-authorized-family-member senior-id tx-sender) ERR_UNAUTHORIZED)

    (map-set notification-preferences
      { senior-id: senior-id, member-address: tx-sender }
      {
        health-updates: (get health-updates preferences-data),
        care-updates: (get care-updates preferences-data),
        emergency-alerts: (get emergency-alerts preferences-data),
        daily-reports: (get daily-reports preferences-data),
        medication-reminders: (get medication-reminders preferences-data),
        appointment-notifications: (get appointment-notifications preferences-data)
      }
    )
    (ok true)
  )
)

(define-public (set-communication-permissions
  (senior-id uint)
  (allow-family-updates bool)
  (allow-caregiver-messages bool)
  (require-approval bool)
  (privacy-level (string-ascii 20))
)
  (begin
    (asserts! (or
      (is-eq privacy-level "public")
      (is-eq privacy-level "family")
      (is-eq privacy-level "private")
    ) ERR_INVALID_DATA)

    (map-set communication-permissions
      { senior-id: senior-id }
      {
        allow-family-updates: allow-family-updates,
        allow-caregiver-messages: allow-caregiver-messages,
        require-approval: require-approval,
        privacy-level: privacy-level
      }
    )
    (ok true)
  )
)

(define-public (post-care-update
  (senior-id uint)
  (update-type (string-ascii 50))
  (title (string-ascii 100))
  (content (string-ascii 1000))
  (priority (string-ascii 20))
  (visibility (string-ascii 20))
)
  (let ((update-id (var-get next-update-id)))
    (asserts! (is-authorized-family-member senior-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (or
      (is-eq priority "low")
      (is-eq priority "medium")
      (is-eq priority "high")
    ) ERR_INVALID_DATA)
    (asserts! (or
      (is-eq visibility "family")
      (is-eq visibility "caregivers")
      (is-eq visibility "all")
    ) ERR_INVALID_DATA)

    (map-set family-care-updates
      { update-id: update-id }
      {
        senior-id: senior-id,
        update-type: update-type,
        title: title,
        content: content,
        priority: priority,
        posted-by: tx-sender,
        posted-at: block-height,
        visibility: visibility
      }
    )
    (var-set next-update-id (+ update-id u1))
    (ok update-id)
  )
)

(define-public (send-message
  (senior-id uint)
  (recipient principal)
  (subject (string-ascii 100))
  (message (string-ascii 500))
)
  (let ((message-id (var-get next-message-id)))
    (asserts! (is-authorized-family-member senior-id tx-sender) ERR_UNAUTHORIZED)

    (map-set communication-messages
      { message-id: message-id }
      {
        senior-id: senior-id,
        sender: tx-sender,
        recipient: recipient,
        subject: subject,
        message: message,
        sent-at: block-height,
        read: false,
        read-at: none
      }
    )
    (var-set next-message-id (+ message-id u1))
    (ok message-id)
  )
)

(define-public (mark-message-read (message-id uint))
  (let ((message (get-communication-message message-id)))
    (asserts! (is-some message) ERR_NOT_FOUND)
    (asserts! (is-eq tx-sender (unwrap-panic (get recipient message))) ERR_UNAUTHORIZED)
    (asserts! (not (unwrap-panic (get read message))) ERR_INVALID_DATA)

    (map-set communication-messages
      { message-id: message-id }
      (merge (unwrap-panic message) {
        read: true,
        read-at: (some block-height)
      })
    )
    (ok true)
  )
)

(define-public (submit-daily-report
  (senior-id uint)
  (activities (string-ascii 300))
  (health-status (string-ascii 200))
  (mood (string-ascii 100))
  (medications (string-ascii 200))
  (concerns (string-ascii 300))
)
  (let ((report-date (/ block-height u144))) ;; Approximate daily blocks
    (asserts! (is-authorized-family-member senior-id tx-sender) ERR_UNAUTHORIZED)

    (map-set daily-reports
      { senior-id: senior-id, report-date: report-date }
      {
        activities-completed: activities,
        health-status: health-status,
        mood-assessment: mood,
        medications-taken: medications,
        concerns: concerns,
        reported-by: tx-sender,
        report-time: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-family-member-activity (senior-id uint))
  (let ((member (get-family-member senior-id tx-sender)))
    (asserts! (is-some member) ERR_NOT_FOUND)

    (map-set family-members
      { senior-id: senior-id, member-address: tx-sender }
      (merge (unwrap-panic member) { last-active: block-height })
    )
    (ok true)
  )
)

(define-public (remove-family-member (senior-id uint) (member-address principal))
  (let ((member (get-family-member senior-id member-address)))
    (asserts! (is-some member) ERR_NOT_FOUND)
    (asserts! (or
      (is-eq tx-sender member-address)
      (has-admin-permission senior-id tx-sender)
    ) ERR_UNAUTHORIZED)

    (map-delete family-members { senior-id: senior-id, member-address: member-address })
    (map-delete notification-preferences { senior-id: senior-id, member-address: member-address })
    (ok true)
  )
)

;; Private functions
(define-private (has-admin-permission (senior-id uint) (member-address principal))
  (let ((member (get-family-member senior-id member-address)))
    (if (is-some member)
      (is-eq (unwrap-panic (get permission-level member)) "admin")
      false
    )
  )
)

(define-private (can-view-update (senior-id uint) (update-visibility (string-ascii 20)) (viewer principal))
  (if (is-eq update-visibility "all")
    true
    (if (is-eq update-visibility "family")
      (is-authorized-family-member senior-id viewer)
      false
    )
  )
)

(define-private (should-notify-member (senior-id uint) (member-address principal) (update-type (string-ascii 50)))
  (let ((preferences (get-notification-preferences senior-id member-address)))
    (if (is-some preferences)
      (if (is-eq update-type "health")
        (unwrap-panic (get health-updates preferences))
        (if (is-eq update-type "care")
          (unwrap-panic (get care-updates preferences))
          true
        )
      )
      true
    )
  )
)
