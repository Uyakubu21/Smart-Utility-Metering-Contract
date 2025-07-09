(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-READING (err u105))

(define-data-var contract-owner principal tx-sender)
(define-data-var water-rate uint u50)
(define-data-var electricity-rate uint u75)

(define-map users principal { 
    balance: uint,
    water-meter-id: (string-ascii 32),
    electricity-meter-id: (string-ascii 32),
    last-water-reading: uint,
    last-electricity-reading: uint,
    last-payment-block: uint,
    total-water-consumed: uint,
    total-electricity-consumed: uint
})

(define-map oracles principal bool)

(define-map meter-readings {
    meter-id: (string-ascii 32),
    reading-block: uint
} {
    reading: uint,
    oracle: principal,
    utility-type: (string-ascii 20)
})

(define-map pending-bills principal {
    water-amount: uint,
    electricity-amount: uint,
    total-due: uint,
    due-block: uint
})

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-water-rate)
    (var-get water-rate)
)

(define-read-only (get-electricity-rate)
    (var-get electricity-rate)
)

(define-read-only (get-user-info (user principal))
    (map-get? users user)
)

(define-read-only (is-oracle (oracle principal))
    (default-to false (map-get? oracles oracle))
)

(define-read-only (get-meter-reading (meter-id (string-ascii 32)) (reading-block uint))
    (map-get? meter-readings {meter-id: meter-id, reading-block: reading-block})
)

(define-read-only (get-pending-bill (user principal))
    (map-get? pending-bills user)
)

(define-read-only (calculate-water-bill (usage uint))
    (* usage (var-get water-rate))
)

(define-read-only (calculate-electricity-bill (usage uint))
    (* usage (var-get electricity-rate))
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-water-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set water-rate new-rate)
        (ok true)
    )
)

(define-public (set-electricity-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set electricity-rate new-rate)
        (ok true)
    )
)

(define-public (add-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (map-set oracles oracle true)
        (ok true)
    )
)

(define-public (remove-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (map-delete oracles oracle)
        (ok true)
    )
)

(define-public (register-user (water-meter-id (string-ascii 32)) (electricity-meter-id (string-ascii 32)))
    (begin
        (asserts! (is-none (map-get? users tx-sender)) ERR-ALREADY-EXISTS)
        (map-set users tx-sender {
            balance: u0,
            water-meter-id: water-meter-id,
            electricity-meter-id: electricity-meter-id,
            last-water-reading: u0,
            last-electricity-reading: u0,
            last-payment-block: stacks-block-height,
            total-water-consumed: u0,
            total-electricity-consumed: u0
        })
        (ok true)
    )
)

(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (match (map-get? users tx-sender)
            user (begin
                (map-set users tx-sender (merge user {balance: (+ (get balance user) amount)}))
                (ok true)
            )
            ERR-NOT-FOUND
        )
    ) 
)

(define-public (submit-reading (meter-id (string-ascii 32)) (reading uint) (utility-type (string-ascii 20)))
    (begin
        (asserts! (is-oracle tx-sender) ERR-UNAUTHORIZED)
        (asserts! (> reading u0) ERR-INVALID-READING)
        (map-set meter-readings {
            meter-id: meter-id,
            reading-block: stacks-block-height
        } {
            reading: reading,
            oracle: tx-sender,
            utility-type: utility-type
        })
        (ok true)
    )
)

(define-public (process-bill (user principal) (water-reading uint) (electricity-reading uint))
    (begin
        (asserts! (is-oracle tx-sender) ERR-UNAUTHORIZED)
        (match (map-get? users user)
            user-data (let (
                (water-usage (- water-reading (get last-water-reading user-data)))
                (electricity-usage (- electricity-reading (get last-electricity-reading user-data)))
                (water-bill (calculate-water-bill water-usage))
                (electricity-bill (calculate-electricity-bill electricity-usage))
                (total-bill (+ water-bill electricity-bill))
            )
            (begin
                (map-set pending-bills user {
                    water-amount: water-bill,
                    electricity-amount: electricity-bill,
                    total-due: total-bill,
                    due-block: (+ stacks-block-height u144)
                })
                (map-set users user (merge user-data {
                    last-water-reading: water-reading,
                    last-electricity-reading: electricity-reading,
                    total-water-consumed: (+ (get total-water-consumed user-data) water-usage),
                    total-electricity-consumed: (+ (get total-electricity-consumed user-data) electricity-usage)
                }))
                (ok total-bill)
            ))
            ERR-NOT-FOUND
        )
    )
)

(define-public (pay-bill)
    (match (map-get? pending-bills tx-sender)
        bill (match (map-get? users tx-sender)
            user (begin
                (asserts! (>= (get balance user) (get total-due bill)) ERR-INSUFFICIENT-FUNDS)
                (map-set users tx-sender (merge user {
                    balance: (- (get balance user) (get total-due bill)),
                    last-payment-block: stacks-block-height
                }))
                (map-delete pending-bills tx-sender)
                (ok true)
            )
            ERR-NOT-FOUND
        )
        ERR-NOT-FOUND
    )
)

(define-public (emergency-withdraw (user principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (match (map-get? users user)
            user-data (begin
                (map-set users user (merge user-data {balance: u0}))
                (ok (get balance user-data))
            )
            ERR-NOT-FOUND
        )
    )
)
