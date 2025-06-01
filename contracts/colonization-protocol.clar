;; Colonization Protocol Contract
;; Plans and manages exoplanet settlement strategies

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROTOCOL_EXISTS (err u201))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u202))
(define-constant ERR_INVALID_PHASE (err u203))
(define-constant ERR_INSTITUTION_NOT_VERIFIED (err u204))

;; Protocol phases
(define-constant PHASE_PLANNING u0)
(define-constant PHASE_REVIEW u1)
(define-constant PHASE_APPROVED u2)
(define-constant PHASE_ACTIVE u3)
(define-constant PHASE_COMPLETED u4)
(define-constant PHASE_CANCELLED u5)

;; Data structures
(define-map colonization-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 100),
    exoplanet-name: (string-ascii 50),
    institution-id: uint,
    phase: uint,
    estimated-population: uint,
    timeline-years: uint,
    resource-requirements: (list 10 (string-ascii 50)),
    safety-rating: uint,
    creation-date: uint,
    approval-date: uint
  }
)

(define-data-var next-protocol-id uint u1)

;; Reference to institution verification contract
(define-trait institution-verifier-trait
  (
    (is-institution-verified (uint) (response bool uint))
  )
)

;; Create a new colonization protocol
(define-public (create-protocol
  (name (string-ascii 100))
  (exoplanet-name (string-ascii 50))
  (institution-id uint)
  (estimated-population uint)
  (timeline-years uint)
  (resource-requirements (list 10 (string-ascii 50)))
  (institution-contract <institution-verifier-trait>)
)
  (let ((protocol-id (var-get next-protocol-id)))
    ;; Verify institution is verified
    (asserts!
      (unwrap! (contract-call? institution-contract is-institution-verified institution-id) ERR_INSTITUTION_NOT_VERIFIED)
      ERR_INSTITUTION_NOT_VERIFIED
    )

    (map-set colonization-protocols
      { protocol-id: protocol-id }
      {
        name: name,
        exoplanet-name: exoplanet-name,
        institution-id: institution-id,
        phase: PHASE_PLANNING,
        estimated-population: estimated-population,
        timeline-years: timeline-years,
        resource-requirements: resource-requirements,
        safety-rating: u0,
        creation-date: block-height,
        approval-date: u0
      }
    )
    (var-set next-protocol-id (+ protocol-id u1))
    (ok protocol-id)
  )
)

;; Update protocol phase
(define-public (update-protocol-phase (protocol-id uint) (new-phase uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-phase PHASE_CANCELLED) ERR_INVALID_PHASE)
    (match (map-get? colonization-protocols { protocol-id: protocol-id })
      protocol-data
      (begin
        (map-set colonization-protocols
          { protocol-id: protocol-id }
          (merge protocol-data {
            phase: new-phase,
            approval-date: (if (is-eq new-phase PHASE_APPROVED) block-height (get approval-date protocol-data))
          })
        )
        (ok true)
      )
      ERR_PROTOCOL_NOT_FOUND
    )
  )
)

;; Set safety rating
(define-public (set-safety-rating (protocol-id uint) (rating uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= rating u100) ERR_INVALID_PHASE)
    (match (map-get? colonization-protocols { protocol-id: protocol-id })
      protocol-data
      (begin
        (map-set colonization-protocols
          { protocol-id: protocol-id }
          (merge protocol-data { safety-rating: rating })
        )
        (ok true)
      )
      ERR_PROTOCOL_NOT_FOUND
    )
  )
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? colonization-protocols { protocol-id: protocol-id })
)

;; Check if protocol is approved
(define-read-only (is-protocol-approved (protocol-id uint))
  (match (map-get? colonization-protocols { protocol-id: protocol-id })
    protocol-data
    (>= (get phase protocol-data) PHASE_APPROVED)
    false
  )
)
