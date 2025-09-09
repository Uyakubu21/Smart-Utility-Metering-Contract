(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-INVALID-READING (err u105))

(define-constant TIER-LOW-THRESHOLD u1000)
(define-constant TIER-MEDIUM-THRESHOLD u3000)
(define-constant TIER-HIGH-THRESHOLD u6000)

(define-constant TIER-LOW-MULTIPLIER u80)
(define-constant TIER-MEDIUM-MULTIPLIER u100)
(define-constant TIER-HIGH-MULTIPLIER u125)
(define-constant TIER-EXCESSIVE-MULTIPLIER u150)

(define-constant ERR-NO-POINTS (err u110))
(define-constant ERR-EXPIRED-POINTS (err u111))

(define-constant PUNCTUAL-PAYMENT-POINTS u100)
(define-constant EFFICIENT-USAGE-POINTS u50)
(define-constant LOYALTY-TENURE-BONUS u25)
(define-constant POINTS-EXPIRY-BLOCKS u4320)

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


(define-map consumption-analytics principal {
    monthly-water-avg: uint,
    monthly-electricity-avg: uint,
    efficiency-score: uint,
    billing-cycles: uint,
    last-analytics-update: uint
})

(define-map tier-statistics (string-ascii 20) {
    tier-users: uint,
    total-consumption: uint,
    revenue-generated: uint
})

(define-read-only (get-consumption-tier (monthly-usage uint))
    (if (<= monthly-usage TIER-LOW-THRESHOLD)
        "low"
        (if (<= monthly-usage TIER-MEDIUM-THRESHOLD)
            "medium"
            (if (<= monthly-usage TIER-HIGH-THRESHOLD)
                "high"
                "excessive"
            )
        )
    )
)

(define-read-only (get-tier-multiplier (tier (string-ascii 20)))
    (if (is-eq tier "low") TIER-LOW-MULTIPLIER
        (if (is-eq tier "medium") TIER-MEDIUM-MULTIPLIER
            (if (is-eq tier "high") TIER-HIGH-MULTIPLIER
                TIER-EXCESSIVE-MULTIPLIER
            )
        )
    )
)

(define-read-only (calculate-tiered-bill (usage uint) (base-rate uint))
    (let ((tier (get-consumption-tier usage))
          (multiplier (get-tier-multiplier tier)))
        (/ (* usage base-rate multiplier) u100)
    )
)

(define-read-only (get-user-analytics (user principal))
    (map-get? consumption-analytics user)
)

(define-read-only (get-tier-stats (tier (string-ascii 20)))
    (map-get? tier-statistics tier)
)

(define-public (update-consumption-analytics (user principal) (water-usage uint) (electricity-usage uint))
    (begin
        (asserts! (is-oracle tx-sender) ERR-UNAUTHORIZED)
        (let ((current-analytics (default-to {
                monthly-water-avg: u0,
                monthly-electricity-avg: u0,
                efficiency-score: u100,
                billing-cycles: u0,
                last-analytics-update: u0
            } (map-get? consumption-analytics user)))
            (cycles (+ (get billing-cycles current-analytics) u1))
            (new-water-avg (/ (+ (* (get monthly-water-avg current-analytics) (get billing-cycles current-analytics)) water-usage) cycles))
            (new-electricity-avg (/ (+ (* (get monthly-electricity-avg current-analytics) (get billing-cycles current-analytics)) electricity-usage) cycles))
            (efficiency (if (and (< new-water-avg TIER-MEDIUM-THRESHOLD) (< new-electricity-avg TIER-MEDIUM-THRESHOLD)) u120 u80)))
            (map-set consumption-analytics user {
                monthly-water-avg: new-water-avg,
                monthly-electricity-avg: new-electricity-avg,
                efficiency-score: efficiency,
                billing-cycles: cycles,
                last-analytics-update: stacks-block-height
            })
            (ok true)
        )
    )
)


(define-map loyalty-points principal {
    total-points: uint,
    points-earned-block: uint,
    consecutive-punctual-payments: uint,
    lifetime-points-earned: uint,
    last-redemption-block: uint
})

(define-map point-transactions {
    user: principal,
    transaction-id: uint
} {
    points-used: uint,
    discount-applied: uint,
    transaction-block: uint,
    transaction-type: (string-ascii 20)
})

(define-data-var transaction-nonce uint u0)

(define-read-only (get-user-loyalty-points (user principal))
    (map-get? loyalty-points user)
)

(define-read-only (calculate-available-points (user principal))
    (match (map-get? loyalty-points user)
        points-data (let (
            (blocks-passed (- stacks-block-height (get points-earned-block points-data)))
        )
        (if (>= blocks-passed POINTS-EXPIRY-BLOCKS)
            u0
            (get total-points points-data)
        ))
        u0
    )
)

(define-read-only (calculate-discount-percentage (points-to-use uint))
    (if (>= points-to-use u500)
        u15
        (if (>= points-to-use u300)
            u10
            (if (>= points-to-use u150)
                u5
                u0
            )
        )
    )
)

(define-public (award-punctual-payment-points (user principal))
    (begin
        (asserts! (is-oracle tx-sender) ERR-UNAUTHORIZED)
        (let (
            (current-points (default-to {
                total-points: u0,
                points-earned-block: stacks-block-height,
                consecutive-punctual-payments: u0,
                lifetime-points-earned: u0,
                last-redemption-block: u0
            } (map-get? loyalty-points user)))
            (consecutive-count (+ (get consecutive-punctual-payments current-points) u1))
            (bonus-multiplier (if (>= consecutive-count u5) u2 u1))
            (points-to-award (* PUNCTUAL-PAYMENT-POINTS bonus-multiplier))
            (tenure-bonus (if (>= consecutive-count u10) LOYALTY-TENURE-BONUS u0))
        )
        (map-set loyalty-points user {
            total-points: (+ (get total-points current-points) points-to-award tenure-bonus),
            points-earned-block: stacks-block-height,
            consecutive-punctual-payments: consecutive-count,
            lifetime-points-earned: (+ (get lifetime-points-earned current-points) points-to-award tenure-bonus),
            last-redemption-block: (get last-redemption-block current-points)
        })
        (ok points-to-award)
        )
    )
)

(define-public (redeem-points-for-discount (points-to-use uint))
    (let (
        (available-points (calculate-available-points tx-sender))
        (discount-percentage (calculate-discount-percentage points-to-use))
        (current-nonce (var-get transaction-nonce))
    )
    (begin
        (asserts! (>= available-points points-to-use) ERR-NO-POINTS)
        (asserts! (> discount-percentage u0) ERR-INVALID-AMOUNT)
        (match (map-get? loyalty-points tx-sender)
            points-data (begin
                (map-set loyalty-points tx-sender (merge points-data {
                    total-points: (- (get total-points points-data) points-to-use),
                    last-redemption-block: stacks-block-height
                }))
                (map-set point-transactions {
                    user: tx-sender,
                    transaction-id: current-nonce
                } {
                    points-used: points-to-use,
                    discount-applied: discount-percentage,
                    transaction-block: stacks-block-height,
                    transaction-type: "discount-redemption"
                })
                (var-set transaction-nonce (+ current-nonce u1))
                (ok discount-percentage)
            )
            ERR-NOT-FOUND
        )
    ))
)