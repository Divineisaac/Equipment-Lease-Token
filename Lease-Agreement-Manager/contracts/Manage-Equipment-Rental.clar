;; Equipment Lease Tokenization Smart Contract
;; This contract enables tokenization of equipment leases with comprehensive functionality

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-LEASE-EXPIRED (err u105))
(define-constant ERR-LEASE-NOT-ACTIVE (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-EQUIPMENT-NOT-AVAILABLE (err u108))
(define-constant ERR-PAYMENT-FAILED (err u109))
(define-constant ERR-INVALID-PRINCIPAL (err u110))
(define-constant ERR-MAINTENANCE-REQUIRED (err u111))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Equipment registry
(define-map equipment-registry
  { equipment-id: uint }
  {
    name: (string-ascii 256),
    description: (string-ascii 512),
    owner: principal,
    value: uint,
    category: (string-ascii 64),
    condition: (string-ascii 32),
    is-available: bool,
    maintenance-due: uint,
    created-at: uint
  }
)

;; Lease agreements
(define-map lease-agreements
  { lease-id: uint }
  {
    equipment-id: uint,
    lessor: principal,
    lessee: principal,
    start-block: uint,
    end-block: uint,
    monthly-payment: uint,
    security-deposit: uint,
    is-active: bool,
    total-paid: uint,
    next-payment-due: uint,
    created-at: uint
  }
)

;; Lease tokens (NFTs representing lease rights)
(define-non-fungible-token lease-token uint)

;; Payment history
(define-map payment-history
  { lease-id: uint, payment-id: uint }
  {
    amount: uint,
    payment-date: uint,
    payment-type: (string-ascii 32),
    paid-by: principal
  }
)

;; Equipment maintenance records
(define-map maintenance-records
  { equipment-id: uint, record-id: uint }
  {
    maintenance-type: (string-ascii 64),
    cost: uint,
    performed-by: principal,
    date: uint,
    description: (string-ascii 256)
  }
)

;; Counter variables
(define-data-var equipment-counter uint u0)
(define-data-var lease-counter uint u0)
(define-data-var payment-counter uint u0)
(define-data-var maintenance-counter uint u0)

;; Platform fee (basis points, e.g., 250 = 2.5%)
(define-data-var platform-fee uint u250)

;; Emergency pause
(define-data-var contract-paused bool false)

;; Equipment categories
(define-constant CATEGORY-CONSTRUCTION "construction")
(define-constant CATEGORY-MEDICAL "medical")
(define-constant CATEGORY-INDUSTRIAL "industrial")
(define-constant CATEGORY-TECHNOLOGY "technology")
(define-constant CATEGORY-AUTOMOTIVE "automotive")

;; Equipment conditions
(define-constant CONDITION-NEW "new")
(define-constant CONDITION-EXCELLENT "excellent")
(define-constant CONDITION-GOOD "good")
(define-constant CONDITION-FAIR "fair")

;; Payment types
(define-constant PAYMENT-MONTHLY "monthly")
(define-constant PAYMENT-DEPOSIT "deposit")
(define-constant PAYMENT-PENALTY "penalty")
(define-constant PAYMENT-MAINTENANCE "maintenance")

;; Modifiers
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-contract-active)
  (not (var-get contract-paused))
)

;; Equipment management functions

;; Register new equipment
(define-public (register-equipment (name (string-ascii 256)) 
                                 (description (string-ascii 512))
                                 (value uint)
                                 (category (string-ascii 64))
                                 (condition (string-ascii 32)))
  (let ((equipment-id (+ (var-get equipment-counter) u1)))
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (> value u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len name) u0) ERR-INVALID-AMOUNT)
    
    (map-set equipment-registry
      { equipment-id: equipment-id }
      {
        name: name,
        description: description,
        owner: tx-sender,
        value: value,
        category: category,
        condition: condition,
        is-available: true,
        maintenance-due: (+ block-height u8640), ;; ~60 days
        created-at: block-height
      }
    )
    
    (var-set equipment-counter equipment-id)
    (ok equipment-id)
  )
)

;; Update equipment availability
(define-public (update-equipment-availability (equipment-id uint) (available bool))
  (let ((equipment (unwrap! (map-get? equipment-registry { equipment-id: equipment-id }) ERR-NOT-FOUND)))
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get owner equipment)) ERR-NOT-AUTHORIZED)
    
    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment { is-available: available })
    )
    (ok true)
  )
)

;; Create lease agreement
(define-public (create-lease (equipment-id uint)
                           (lessee principal)
                           (duration-blocks uint)
                           (monthly-payment uint)
                           (security-deposit uint))
  (let (
    (equipment (unwrap! (map-get? equipment-registry { equipment-id: equipment-id }) ERR-NOT-FOUND))
    (lease-id (+ (var-get lease-counter) u1))
  )
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get owner equipment)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-available equipment) ERR-EQUIPMENT-NOT-AVAILABLE)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    (asserts! (> monthly-payment u0) ERR-INVALID-AMOUNT)
    (asserts! (is-standard lessee) ERR-INVALID-PRINCIPAL)
    
    ;; Create lease agreement
    (map-set lease-agreements
      { lease-id: lease-id }
      {
        equipment-id: equipment-id,
        lessor: tx-sender,
        lessee: lessee,
        start-block: block-height,
        end-block: (+ block-height duration-blocks),
        monthly-payment: monthly-payment,
        security-deposit: security-deposit,
        is-active: false, ;; Will be activated upon first payment
        total-paid: u0,
        next-payment-due: (+ block-height u4320), ;; ~30 days
        created-at: block-height
      }
    )
    
    ;; Mark equipment as unavailable
    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment { is-available: false })
    )
    
    ;; Mint lease token to lessee
    (try! (nft-mint? lease-token lease-id lessee))
    
    (var-set lease-counter lease-id)
    (ok lease-id)
  )
)

;; Make lease payment
(define-public (make-payment (lease-id uint) (payment-type (string-ascii 32)))
  (let (
    (lease (unwrap! (map-get? lease-agreements { lease-id: lease-id }) ERR-NOT-FOUND))
    (payment-id (+ (var-get payment-counter) u1))
    (payment-amount (if (is-eq payment-type PAYMENT-DEPOSIT)
                      (get security-deposit lease)
                      (get monthly-payment lease)))
    (platform-fee-amount (/ (* payment-amount (var-get platform-fee)) u10000))
    (lessor-amount (- payment-amount platform-fee-amount))
  )
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq tx-sender (get lessee lease)) 
                  (is-eq tx-sender (get lessor lease))) ERR-NOT-AUTHORIZED)
    (asserts! (<= block-height (get end-block lease)) ERR-LEASE-EXPIRED)
    
    ;; Transfer payment from lessee to lessor
    (try! (stx-transfer? lessor-amount tx-sender (get lessor lease)))
    
    ;; Transfer platform fee to contract owner (if applicable)
    (if (> platform-fee-amount u0)
      (try! (stx-transfer? platform-fee-amount tx-sender (var-get contract-owner)))
      true
    )
    
    ;; Record payment
    (map-set payment-history
      { lease-id: lease-id, payment-id: payment-id }
      {
        amount: payment-amount,
        payment-date: block-height,
        payment-type: payment-type,
        paid-by: tx-sender
      }
    )
    
    ;; Update lease agreement
    (let ((updated-lease (merge lease {
      is-active: true,
      total-paid: (+ (get total-paid lease) payment-amount),
      next-payment-due: (if (is-eq payment-type PAYMENT-MONTHLY)
                         (+ block-height u4320) ;; Next month
                         (get next-payment-due lease))
    })))
      (map-set lease-agreements { lease-id: lease-id } updated-lease)
    )
    
    (var-set payment-counter payment-id)
    (ok payment-id)
  )
)

;; Terminate lease
(define-public (terminate-lease (lease-id uint))
  (let ((lease (unwrap! (map-get? lease-agreements { lease-id: lease-id }) ERR-NOT-FOUND)))
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq tx-sender (get lessor lease))
                  (is-eq tx-sender (get lessee lease))) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active lease) ERR-LEASE-NOT-ACTIVE)
    
    ;; Update lease status
    (map-set lease-agreements
      { lease-id: lease-id }
      (merge lease { is-active: false })
    )
    
    ;; Make equipment available again
    (let ((equipment (unwrap! (map-get? equipment-registry { equipment-id: (get equipment-id lease) }) ERR-NOT-FOUND)))
      (map-set equipment-registry
        { equipment-id: (get equipment-id lease) }
        (merge equipment { is-available: true })
      )
    )
    
    ;; Burn lease token
    (try! (nft-burn? lease-token lease-id (get lessee lease)))
    
    (ok true)
  )
)

;; Record maintenance
(define-public (record-maintenance (equipment-id uint)
                                 (maintenance-type (string-ascii 64))
                                 (cost uint)
                                 (description (string-ascii 256)))
  (let (
    (equipment (unwrap! (map-get? equipment-registry { equipment-id: equipment-id }) ERR-NOT-FOUND))
    (record-id (+ (var-get maintenance-counter) u1))
  )
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get owner equipment)) ERR-NOT-AUTHORIZED)
    
    (map-set maintenance-records
      { equipment-id: equipment-id, record-id: record-id }
      {
        maintenance-type: maintenance-type,
        cost: cost,
        performed-by: tx-sender,
        date: block-height,
        description: description
      }
    )
    
    ;; Update maintenance due date (extend by ~60 days)
    (map-set equipment-registry
      { equipment-id: equipment-id }
      (merge equipment { maintenance-due: (+ block-height u8640) })
    )
    
    (var-set maintenance-counter record-id)
    (ok record-id)
  )
)

;; Transfer lease token
(define-public (transfer-lease-token (lease-id uint) (new-owner principal))
  (let ((lease (unwrap! (map-get? lease-agreements { lease-id: lease-id }) ERR-NOT-FOUND)))
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get lessee lease)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active lease) ERR-LEASE-NOT-ACTIVE)
    (asserts! (is-standard new-owner) ERR-INVALID-PRINCIPAL)
    
    ;; Transfer NFT
    (try! (nft-transfer? lease-token lease-id tx-sender new-owner))
    
    ;; Update lease agreement
    (map-set lease-agreements
      { lease-id: lease-id }
      (merge lease { lessee: new-owner })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get equipment details
(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment-registry { equipment-id: equipment-id })
)

;; Get lease details
(define-read-only (get-lease (lease-id uint))
  (map-get? lease-agreements { lease-id: lease-id })
)

;; Get payment history
(define-read-only (get-payment (lease-id uint) (payment-id uint))
  (map-get? payment-history { lease-id: lease-id, payment-id: payment-id })
)

;; Get maintenance record
(define-read-only (get-maintenance-record (equipment-id uint) (record-id uint))
  (map-get? maintenance-records { equipment-id: equipment-id, record-id: record-id })
)

;; Check if lease is overdue
(define-read-only (is-lease-overdue (lease-id uint))
  (match (map-get? lease-agreements { lease-id: lease-id })
    lease (and (get is-active lease) (> block-height (get next-payment-due lease)))
    false
  )
)

;; Check if equipment needs maintenance
(define-read-only (needs-maintenance (equipment-id uint))
  (match (map-get? equipment-registry { equipment-id: equipment-id })
    equipment (>= block-height (get maintenance-due equipment))
    false
  )
)

;; Get lease token owner
(define-read-only (get-lease-token-owner (lease-id uint))
  (nft-get-owner? lease-token lease-id)
)

;; Get equipment by owner
(define-read-only (get-equipment-count)
  (var-get equipment-counter)
)

;; Get lease count
(define-read-only (get-lease-count)
  (var-get lease-counter)
)

;; Administrative functions

;; Update contract owner
(define-public (update-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-standard new-owner) ERR-INVALID-PRINCIPAL)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Update platform fee
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT) ;; Max 10%
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Pause/unpause contract
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; Emergency withdrawal (only owner)
(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (var-get contract-paused) ERR-NOT-AUTHORIZED)
    (try! (stx-transfer? amount (as-contract tx-sender) (var-get contract-owner)))
    (ok true)
  )
)