
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-loan-exists (err u105))
(define-constant err-loan-not-active (err u106))
(define-constant err-payment-failed (err u107))
(define-constant err-already-funded (err u108))
(define-constant err-funding-complete (err u109))
(define-constant err-loan-defaulted (err u110))
(define-constant err-loan-completed (err u111))
(define-constant err-refinance-invalid (err u112))

(define-data-var next-loan-id uint u1)
(define-data-var platform-fee-rate uint u250)
(define-data-var default-threshold-days uint u90)

(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    loan-amount: uint,
    funded-amount: uint,
    interest-rate: uint,
    term-months: uint,
    monthly-payment: uint,
    installation-cost: uint,
    panel-specs: (string-ascii 256),
    created-at: uint,
    funded-at: (optional uint),
    last-payment: (optional uint),
    payments-made: uint,
    status: (string-ascii 20),
    collateral-percentage: uint
  }
)

(define-map lender-contributions
  { loan-id: uint, lender: principal }
  { amount: uint, funded-at: uint }
)

(define-map loan-lenders
  { loan-id: uint }
  { lenders: (list 50 principal), total-lenders: uint }
)

(define-map borrower-loans
  { borrower: principal }
  { loan-ids: (list 10 uint), total-loans: uint }
)

(define-map lender-portfolio
  { lender: principal }
  { loan-ids: (list 50 uint), total-invested: uint, active-loans: uint }
)

(define-map solar-installations
  { loan-id: uint }
  {
    installation-address: (string-ascii 256),
    panel-capacity: uint,
    estimated-monthly-generation: uint,
    installer-principal: principal,
    installation-date: (optional uint),
    verification-status: (string-ascii 20)
  }
)

(define-map usage-reports
  { loan-id: uint, report-month: uint }
  { energy-generated: uint, reported-by: principal, report-date: uint }
)

(define-map refinance-history
  { original-loan-id: uint }
  { new-loan-id: uint, refinanced-at: uint, old-interest-rate: uint, new-interest-rate: uint }
)

(define-public (create-loan-request 
    (loan-amount uint)
    (interest-rate uint)
    (term-months uint)
    (installation-cost uint)
    (panel-specs (string-ascii 256))
    (collateral-percentage uint)
    (installation-address (string-ascii 256))
    (panel-capacity uint)
    (estimated-monthly-generation uint)
    (installer-principal principal)
  )
  (let
    (
      (loan-id (var-get next-loan-id))
      (monthly-payment (calculate-monthly-payment loan-amount interest-rate term-months))
    )
    (asserts! (> loan-amount u0) err-invalid-amount)
    (asserts! (> interest-rate u0) err-invalid-amount)
    (asserts! (> term-months u0) err-invalid-amount)
    (asserts! (<= collateral-percentage u100) err-invalid-amount)
    (asserts! (is-none (map-get? loans { loan-id: loan-id })) err-loan-exists)
    
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: tx-sender,
        loan-amount: loan-amount,
        funded-amount: u0,
        interest-rate: interest-rate,
        term-months: term-months,
        monthly-payment: monthly-payment,
        installation-cost: installation-cost,
        panel-specs: panel-specs,
        created-at: stacks-block-height,
        funded-at: none,
        last-payment: none,
        payments-made: u0,
        status: "pending",
        collateral-percentage: collateral-percentage
      }
    )
    
    (map-set solar-installations
      { loan-id: loan-id }
      {
        installation-address: installation-address,
        panel-capacity: panel-capacity,
        estimated-monthly-generation: estimated-monthly-generation,
        installer-principal: installer-principal,
        installation-date: none,
        verification-status: "pending"
      }
    )
    
    (update-borrower-loans tx-sender loan-id)
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (remaining-amount (- (get loan-amount loan) (get funded-amount loan)))
      (contribution-amount (if (> amount remaining-amount) remaining-amount amount))
      (new-funded-amount (+ (get funded-amount loan) contribution-amount))
    )
    (asserts! (is-eq (get status loan) "pending") err-loan-not-active)
    (asserts! (> contribution-amount u0) err-invalid-amount)
    (asserts! (< (get funded-amount loan) (get loan-amount loan)) err-already-funded)
    
    (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
    
    (map-set lender-contributions
      { loan-id: loan-id, lender: tx-sender }
      { amount: contribution-amount, funded-at: stacks-block-height }
    )
    
    (add-lender-to-loan loan-id tx-sender)
    (update-lender-portfolio tx-sender loan-id contribution-amount)
    
    (map-set loans
      { loan-id: loan-id }
      (merge loan { funded-amount: new-funded-amount })
    )
    
    (if (>= new-funded-amount (get loan-amount loan))
      (begin
        (map-set loans
          { loan-id: loan-id }
          (merge loan {
            funded-amount: new-funded-amount,
            status: "funded",
            funded-at: (some stacks-block-height)
          })
        )
        (try! (stx-transfer? new-funded-amount (as-contract tx-sender) (get borrower loan)))
        (ok "loan-fully-funded")
      )
      (ok "partial-funding-complete")
    )
  )
)

(define-public (make-payment (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (payment-amount (get monthly-payment loan))
      (platform-fee (/ (* payment-amount (var-get platform-fee-rate)) u10000))
      (lender-payment (- payment-amount platform-fee))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (is-eq (get status loan) "funded") err-loan-not-active)
    
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    
    (unwrap-panic (distribute-payment-to-lenders loan-id lender-payment))
    (try! (stx-transfer? platform-fee (as-contract tx-sender) contract-owner))
    
    (let ((new-payments-made (+ (get payments-made loan) u1)))
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          last-payment: (some stacks-block-height),
          payments-made: new-payments-made,
          status: (if (>= new-payments-made (get term-months loan)) "completed" "funded")
        })
      )
    )
    
    (ok "payment-successful")
  )
)

(define-public (report-energy-generation (loan-id uint) (energy-generated uint) (report-month uint))
  (let
    (
      (installation (unwrap! (map-get? solar-installations { loan-id: loan-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get installer-principal installation)) err-unauthorized)
    
    (map-set usage-reports
      { loan-id: loan-id, report-month: report-month }
      {
        energy-generated: energy-generated,
        reported-by: tx-sender,
        report-date: stacks-block-height
      }
    )
    
    (ok "report-submitted")
  )
)

(define-public (verify-installation (loan-id uint))
  (let
    (
      (installation (unwrap! (map-get? solar-installations { loan-id: loan-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set solar-installations
      { loan-id: loan-id }
      (merge installation {
        installation-date: (some stacks-block-height),
        verification-status: "verified"
      })
    )
    
    (ok "installation-verified")
  )
)

(define-public (initiate-default-process (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
      (last-payment-block (default-to u0 (get last-payment loan)))
      (blocks-since-payment (- stacks-block-height last-payment-block))
      (default-threshold-blocks (* (var-get default-threshold-days) u144))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status loan) "funded") err-loan-not-active)
    (asserts! (> blocks-since-payment default-threshold-blocks) err-unauthorized)
    
    (map-set loans
      { loan-id: loan-id }
      (merge loan { status: "defaulted" })
    )
    
    (ok "default-initiated")
  )
)

(define-public (set-platform-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee-rate u1000) err-invalid-amount)
    (var-set platform-fee-rate new-fee-rate)
    (ok "fee-updated")
  )
)

(define-public (refinance-loan 
    (original-loan-id uint)
    (new-interest-rate uint)
    (new-term-months uint)
  )
  (let
    (
      (original-loan (unwrap! (map-get? loans { loan-id: original-loan-id }) err-not-found))
      (remaining-balance (calculate-remaining-balance original-loan-id))
      (new-loan-id (var-get next-loan-id))
      (new-monthly-payment (calculate-monthly-payment remaining-balance new-interest-rate new-term-months))
      (installation (unwrap! (map-get? solar-installations { loan-id: original-loan-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get borrower original-loan)) err-unauthorized)
    (asserts! (is-eq (get status original-loan) "funded") err-loan-not-active)
    (asserts! (> (get payments-made original-loan) u0) err-refinance-invalid)
    (asserts! (> remaining-balance u0) err-invalid-amount)
    (asserts! (> new-interest-rate u0) err-invalid-amount)
    (asserts! (> new-term-months u0) err-invalid-amount)
    (asserts! (< new-interest-rate (get interest-rate original-loan)) err-refinance-invalid)
    
    (map-set loans
      { loan-id: original-loan-id }
      (merge original-loan { status: "refinanced" })
    )
    
    (map-set loans
      { loan-id: new-loan-id }
      {
        borrower: tx-sender,
        loan-amount: remaining-balance,
        funded-amount: remaining-balance,
        interest-rate: new-interest-rate,
        term-months: new-term-months,
        monthly-payment: new-monthly-payment,
        installation-cost: (get installation-cost original-loan),
        panel-specs: (get panel-specs original-loan),
        created-at: stacks-block-height,
        funded-at: (some stacks-block-height),
        last-payment: none,
        payments-made: u0,
        status: "funded",
        collateral-percentage: (get collateral-percentage original-loan)
      }
    )
    
    (map-set solar-installations
      { loan-id: new-loan-id }
      {
        installation-address: (get installation-address installation),
        panel-capacity: (get panel-capacity installation),
        estimated-monthly-generation: (get estimated-monthly-generation installation),
        installer-principal: (get installer-principal installation),
        installation-date: (get installation-date installation),
        verification-status: (get verification-status installation)
      }
    )
    
    (map-set refinance-history
      { original-loan-id: original-loan-id }
      {
        new-loan-id: new-loan-id,
        refinanced-at: stacks-block-height,
        old-interest-rate: (get interest-rate original-loan),
        new-interest-rate: new-interest-rate
      }
    )
    
    (update-borrower-loans tx-sender new-loan-id)
    (unwrap-panic (migrate-lender-contributions original-loan-id new-loan-id))
    (var-set next-loan-id (+ new-loan-id u1))
    (ok new-loan-id)
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-solar-installation (loan-id uint))
  (map-get? solar-installations { loan-id: loan-id })
)

(define-read-only (get-usage-report (loan-id uint) (report-month uint))
  (map-get? usage-reports { loan-id: loan-id, report-month: report-month })
)

(define-read-only (get-lender-contribution (loan-id uint) (lender principal))
  (map-get? lender-contributions { loan-id: loan-id, lender: lender })
)

(define-read-only (get-borrower-loans (borrower principal))
  (map-get? borrower-loans { borrower: borrower })
)

(define-read-only (get-lender-portfolio (lender principal))
  (map-get? lender-portfolio { lender: lender })
)

(define-read-only (get-refinance-history (original-loan-id uint))
  (map-get? refinance-history { original-loan-id: original-loan-id })
)

(define-read-only (calculate-remaining-balance (loan-id uint))
  (let
    (
      (loan (unwrap-panic (map-get? loans { loan-id: loan-id })))
      (total-to-repay (+ (get loan-amount loan) (/ (* (get loan-amount loan) (get interest-rate loan) (get term-months loan)) (* u12 u100))))
      (paid-so-far (* (get monthly-payment loan) (get payments-made loan)))
    )
    (if (> total-to-repay paid-so-far)
      (- total-to-repay paid-so-far)
      u0
    )
  )
)

(define-read-only (calculate-monthly-payment (principal uint) (annual-rate uint) (months uint))
  (let
    (
      (monthly-rate (/ annual-rate (* u12 u100)))
      (rate-plus-one (+ u10000 monthly-rate))
      (power-term (pow rate-plus-one months))
      (numerator (* principal (* monthly-rate power-term)))
      (denominator (- power-term u10000))
    )
    (if (is-eq monthly-rate u0)
      (/ principal months)
      (/ numerator denominator)
    )
  )
)

(define-private (distribute-payment-to-lenders (loan-id uint) (total-amount uint))
  (let
    (
      (loan (unwrap-panic (map-get? loans { loan-id: loan-id })))
      (loan-amount (get loan-amount loan))
    )
    (ok "payment-distributed")
  )
)

(define-private (add-lender-to-loan (loan-id uint) (lender principal))
  (let
    (
      (current-lenders (default-to { lenders: (list), total-lenders: u0 } 
                       (map-get? loan-lenders { loan-id: loan-id })))
    )
    (map-set loan-lenders
      { loan-id: loan-id }
      {
        lenders: (unwrap-panic (as-max-len? (append (get lenders current-lenders) lender) u50)),
        total-lenders: (+ (get total-lenders current-lenders) u1)
      }
    )
  )
)

(define-private (update-borrower-loans (borrower principal) (loan-id uint))
  (let
    (
      (current-loans (default-to { loan-ids: (list), total-loans: u0 } 
                     (map-get? borrower-loans { borrower: borrower })))
    )
    (map-set borrower-loans
      { borrower: borrower }
      {
        loan-ids: (unwrap-panic (as-max-len? (append (get loan-ids current-loans) loan-id) u10)),
        total-loans: (+ (get total-loans current-loans) u1)
      }
    )
  )
)

(define-private (update-lender-portfolio (lender principal) (loan-id uint) (amount uint))
  (let
    (
      (current-portfolio (default-to { loan-ids: (list), total-invested: u0, active-loans: u0 } 
                         (map-get? lender-portfolio { lender: lender })))
    )
    (map-set lender-portfolio
      { lender: lender }
      {
        loan-ids: (unwrap-panic (as-max-len? (append (get loan-ids current-portfolio) loan-id) u50)),
        total-invested: (+ (get total-invested current-portfolio) amount),
        active-loans: (+ (get active-loans current-portfolio) u1)
      }
    )
  )
)

(define-private (migrate-lender-contributions (old-loan-id uint) (new-loan-id uint))
  (let
    (
      (loan-lender-data (default-to { lenders: (list), total-lenders: u0 } 
                        (map-get? loan-lenders { loan-id: old-loan-id })))
      (lenders-list (get lenders loan-lender-data))
    )
    (map-set loan-lenders
      { loan-id: new-loan-id }
      loan-lender-data
    )
    (ok true)
  )
)

