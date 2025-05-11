;; Payroll System Smart Contract
;; Description: A comprehensive payroll system that allows adding employees, 
;; processing payroll, managing benefits, and handling tax withholdings.

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_EMPLOYEE_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_EMPLOYEE_EXISTS (err u103))
(define-constant ERR_INVALID_AMOUNT (err u104))
(define-constant ERR_INVALID_DATE (err u105))
(define-constant ERR_PAYMENT_ALREADY_PROCESSED (err u106))

;; Data structures
(define-map employees 
  { employee-id: (string-ascii 36) } 
  {
    address: principal,
    name: (string-ascii 50),
    salary: uint,
    hourly-rate: uint,
    is-hourly: bool,
    benefits-rate: uint,
    tax-rate: uint,
    last-paid: uint,
    active: bool
  }
)

(define-map payroll-history
  { 
    employee-id: (string-ascii 36),
    period-end: uint
  }
  {
    gross-amount: uint,
    tax-amount: uint,
    benefits-amount: uint,
    net-amount: uint,
    timestamp: uint,
    paid: bool
  }
)

(define-map hours-worked
  {
    employee-id: (string-ascii 36),
    period-end: uint
  }
  { hours: uint }
)

(define-data-var contract-balance uint u0)
(define-data-var next-payday uint u0)
(define-data-var pay-period-length uint u1209600) ;; Default: 2 weeks in seconds (14 * 24 * 60 * 60)

;; Read-only functions

;; Get employee details
(define-read-only (get-employee (employee-id (string-ascii 36)))
  (map-get? employees { employee-id: employee-id })
)

;; Get employee payment history
(define-read-only (get-payment-history (employee-id (string-ascii 36)) (period-end uint))
  (map-get? payroll-history { employee-id: employee-id, period-end: period-end })
)

;; Get recorded hours for an employee in a period
(define-read-only (get-hours (employee-id (string-ascii 36)) (period-end uint))
  (default-to { hours: u0 }
    (map-get? hours-worked { employee-id: employee-id, period-end: period-end })
  )
)

;; Get contract balance
(define-read-only (get-balance)
  (var-get contract-balance)
)

;; Get the next scheduled payday
(define-read-only (get-next-payday)
  (var-get next-payday)
)

;; Get current pay period length in seconds
(define-read-only (get-pay-period-length)
  (var-get pay-period-length)
)

;; Check if an employee exists
(define-read-only (employee-exists (employee-id (string-ascii 36)))
  (is-some (map-get? employees { employee-id: employee-id }))
)

;; Calculate the amount to pay an employee for a period
(define-read-only (calculate-payment (employee-id (string-ascii 36)) (period-end uint))
  (let (
    (employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND))
    (hours (get hours (get-hours employee-id period-end)))
    (gross-amount (if (get is-hourly employee)
                      (mul (get hourly-rate employee) hours)
                      (get salary employee)))
    (tax-amount (div (mul gross-amount (get tax-rate employee)) u10000))
    (benefits-amount (div (mul gross-amount (get benefits-rate employee)) u10000))
    (net-amount (- (- gross-amount tax-amount) benefits-amount))
  )
  {
    gross-amount: gross-amount,
    tax-amount: tax-amount,
    benefits-amount: benefits-amount,
    net-amount: net-amount
  })
)

;; List all active employees
(define-read-only (list-active-employees)
  (filter active-employees (map-to-list employees))
)

;; Helper function for filtering active employees
(define-private (active-employees (entry {employee-id: (string-ascii 36), value: {
    address: principal,
    name: (string-ascii 50),
    salary: uint,
    hourly-rate: uint,
    is-hourly: bool,
    benefits-rate: uint,
    tax-rate: uint,
    last-paid: uint,
    active: bool
  }}))
  (get active (get value entry))
)

;; Public functions

;; Add funds to the contract
(define-public (add-funds (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok amount)
  )
)

;; Add a new employee
(define-public (add-employee 
  (employee-id (string-ascii 36))
  (employee-address principal)
  (name (string-ascii 50))
  (salary uint)
  (hourly-rate uint)
  (is-hourly bool)
  (benefits-rate uint)  ;; Basis points (1/100 of 1%)
  (tax-rate uint)       ;; Basis points (1/100 of 1%)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (not (employee-exists employee-id)) ERR_EMPLOYEE_EXISTS)
    (asserts! (or (and is-hourly (> hourly-rate u0) (is-eq salary u0))
                 (and (not is-hourly) (> salary u0) (is-eq hourly-rate u0)))
             ERR_INVALID_AMOUNT)
    
    (map-set employees
      { employee-id: employee-id }
      {
        address: employee-address,
        name: name,
        salary: salary,
        hourly-rate: hourly-rate,
        is-hourly: is-hourly,
        benefits-rate: benefits-rate,
        tax-rate: tax-rate,
        last-paid: u0,
        active: true
      }
    )
    (ok true)
  )
)

;; Update an existing employee
(define-public (update-employee 
  (employee-id (string-ascii 36))
  (employee-address principal)
  (name (string-ascii 50))
  (salary uint)
  (hourly-rate uint)
  (is-hourly bool)
  (benefits-rate uint)
  (tax-rate uint)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (employee-exists employee-id) ERR_EMPLOYEE_NOT_FOUND)
    (asserts! (or (and is-hourly (> hourly-rate u0) (is-eq salary u0))
                 (and (not is-hourly) (> salary u0) (is-eq hourly-rate u0)))
             ERR_INVALID_AMOUNT)
    
    (let ((employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND)))
      (map-set employees
        { employee-id: employee-id }
        {
          address: employee-address,
          name: name,
          salary: salary,
          hourly-rate: hourly-rate,
          is-hourly: is-hourly,
          benefits-rate: benefits-rate,
          tax-rate: tax-rate,
          last-paid: (get last-paid employee),
          active: (get active employee)
        }
      )
    )
    (ok true)
  )
)

;; Deactivate an employee (instead of deleting)
(define-public (deactivate-employee (employee-id (string-ascii 36)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (employee-exists employee-id) ERR_EMPLOYEE_NOT_FOUND)
    
    (let ((employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND)))
      (map-set employees
        { employee-id: employee-id }
        {
          address: (get address employee),
          name: (get name employee),
          salary: (get salary employee),
          hourly-rate: (get hourly-rate employee),
          is-hourly: (get is-hourly employee),
          benefits-rate: (get benefits-rate employee),
          tax-rate: (get tax-rate employee),
          last-paid: (get last-paid employee),
          active: false
        }
      )
    )
    (ok true)
  )
)

;; Reactivate an employee
(define-public (reactivate-employee (employee-id (string-ascii 36)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (employee-exists employee-id) ERR_EMPLOYEE_NOT_FOUND)
    
    (let ((employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND)))
      (map-set employees
        { employee-id: employee-id }
        {
          address: (get address employee),
          name: (get name employee),
          salary: (get salary employee),
          hourly-rate: (get hourly-rate employee),
          is-hourly: (get is-hourly employee),
          benefits-rate: (get benefits-rate employee),
          tax-rate: (get tax-rate employee),
          last-paid: (get last-paid employee),
          active: true
        }
      )
    )
    (ok true)
  )
)

;; Record hours worked for hourly employees
(define-public (record-hours (employee-id (string-ascii 36)) (period-end uint) (hours-count uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (employee-exists employee-id) ERR_EMPLOYEE_NOT_FOUND)
    (asserts! (> hours-count u0) ERR_INVALID_AMOUNT)
    
    (let ((employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND)))
      (asserts! (get is-hourly employee) ERR_NOT_AUTHORIZED)
      
      (map-set hours-worked
        { employee-id: employee-id, period-end: period-end }
        { hours: hours-count }
      )
    )
    (ok true)
  )
)

;; Process payment for a single employee
(define-public (process-payment (employee-id (string-ascii 36)) (period-end uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (employee-exists employee-id) ERR_EMPLOYEE_NOT_FOUND)
    
    ;; Check if payment already processed
    (asserts! (is-none (map-get? payroll-history 
                                { employee-id: employee-id, period-end: period-end }))
             ERR_PAYMENT_ALREADY_PROCESSED)
    
    (let (
      (employee (unwrap! (map-get? employees { employee-id: employee-id }) ERR_EMPLOYEE_NOT_FOUND))
      (payment-details (calculate-payment employee-id period-end))
      (gross-amount (get gross-amount payment-details))
      (tax-amount (get tax-amount payment-details))
      (benefits-amount (get benefits-amount payment-details))
      (net-amount (get net-amount payment-details))
      (current-time (unwrap! (get-block-info? time (get-block-height)) ERR_INVALID_DATE))
    )
      ;; Check if employee is active
      (asserts! (get active employee) ERR_NOT_AUTHORIZED)
      
      ;; Check contract has enough funds
      (asserts! (>= (var-get contract-balance) net-amount) ERR_INSUFFICIENT_FUNDS)
      
      ;; Record the payment
      (map-set payroll-history
        { employee-id: employee-id, period-end: period-end }
        {
          gross-amount: gross-amount,
          tax-amount: tax-amount,
          benefits-amount: benefits-amount,
          net-amount: net-amount,
          timestamp: current-time,
          paid: true
        }
      )
      
      ;; Update employee's last paid timestamp
      (map-set employees
        { employee-id: employee-id }
        {
          address: (get address employee),
          name: (get name employee),
          salary: (get salary employee),
          hourly-rate: (get hourly-rate employee),
          is-hourly: (get is-hourly employee),
          benefits-rate: (get benefits-rate employee),
          tax-rate: (get tax-rate employee),
          last-paid: current-time,
          active: (get active employee)
        }
      )
      
      ;; Update contract balance
      (var-set contract-balance (- (var-get contract-balance) net-amount))
      
      (ok net-amount)
    )
  )
)

;; Run a full payroll for all active employees
(define-public (run-payroll (period-end uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (let (
      (current-time (unwrap! (get-block-info? time (get-block-height)) ERR_INVALID_DATE))
    )
      ;; Set next payday
      (var-set next-payday (+ period-end (var-get pay-period-length)))
      
      ;; Process payroll for each active employee
      ;; Note: In practice, we would need to iterate through employees
      ;; This is a limitation in Clarity, as it doesn't support loops
      ;; An off-chain solution would need to call process-payment for each employee
      
      (ok true)
    )
  )
)

;; Update the pay period length
(define-public (set-pay-period-length (new-length uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-length u0) ERR_INVALID_AMOUNT)
    (var-set pay-period-length new-length)
    (ok true)
  )
)

;; Initialize the contract
(define-public (initialize (first-payday uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (var-get next-payday) u0) ERR_NOT_AUTHORIZED)
    (var-set next-payday first-payday)
    (ok true)
  )
)

;; Withdraw funds from the contract (only owner)
(define-public (withdraw-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= amount (var-get contract-balance)) ERR_INSUFFICIENT_FUNDS)
    (var-set contract-balance (- (var-get contract-balance) amount))
    (ok amount)
  )
)