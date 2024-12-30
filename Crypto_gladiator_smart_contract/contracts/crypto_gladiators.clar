;; CryptoGladiators
;; A blockchain-based character collection and battle system
;; Where players can mint, trade, and battle with unique characters

;; Error codes
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_TRANSFER_FAILED (err u402))
(define-constant ERR_COOLDOWN (err u403))
(define-constant ERR_INVALID_INPUT (err u400))

;; Define constants for game parameters
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINT_PRICE u100000) ;; in microSTX
(define-constant MAX_LEVEL u100)
(define-constant BASE_XP_REQUIRED u100)
(define-constant MIN_PRICE u1000) ;; Minimum listing price
(define-constant MAX_CHARACTERS_PER_USER u100) ;; Maximum characters per user

;; Define custom types for our characters
(define-data-var last-character-id uint u0)

(define-map characters
    uint
    {
        owner: principal,
        name: (string-ascii 24),
        level: uint,
        xp: uint,
        attack: uint,
        defense: uint,
        last-battle-block: uint
    }
)

;; Keep track of ownership counts
(define-map user-character-count principal uint)

;; Market listings
(define-map market
    uint  ;; character ID
    {
        price: uint,
        seller: principal
    }
)

;; Read-only functions
(define-read-only (get-character (character-id uint))
    (map-get? characters character-id)
)

(define-read-only (get-listing (character-id uint))
    (map-get? market character-id)
)

(define-read-only (get-owner-count (user principal))
    (default-to u0 (map-get? user-character-count user))
)

;; Helper function to get owner of a character
(define-read-only (get-owner (character-id uint))
    (match (get-character character-id)
        character (ok (get owner character))
        ERR_NOT_FOUND
    )
)

;; Input validation functions
(define-private (is-valid-character-id (character-id uint))
    (<= character-id (var-get last-character-id))
)

(define-private (is-valid-price (price uint))
    (>= price MIN_PRICE)
)

(define-private (is-valid-name (name (string-ascii 24)))
    (and 
        (> (len name) u0)
        (<= (len name) u24)
    )
)

;; Helper function to generate pseudo-random number between 1 and 10
(define-private (generate-stat (seed uint))
    (let
        (
            (hash (sha256 block-height))
        )
        (+ (mod (len hash) u10) u1)
    )
)

;; Public functions
(define-public (mint-character (name (string-ascii 24)))
    (let
        (
            (new-id (+ (var-get last-character-id) u1))
            (caller tx-sender)
            (current-count (get-owner-count caller))
        )
        ;; Input validation
        (asserts! (is-valid-name name) ERR_INVALID_INPUT)
        (asserts! (< current-count MAX_CHARACTERS_PER_USER) ERR_INVALID_INPUT)
        
        (try! (stx-transfer? MINT_PRICE caller CONTRACT_OWNER))
        
        ;; Create character with random initial stats using block height as seed
        (map-set characters new-id {
            owner: caller,
            name: name,
            level: u1,
            xp: u0,
            attack: (generate-stat new-id),
            defense: (generate-stat (+ new-id u1)),
            last-battle-block: u0
        })
        
        ;; Update ownership count
        (map-set user-character-count caller (+ current-count u1))
        (var-set last-character-id new-id)
        (ok new-id)
    )
)

(define-public (list-for-sale (character-id uint) (price uint))
    (begin
        ;; Input validation
        (asserts! (is-valid-character-id character-id) ERR_INVALID_INPUT)
        (asserts! (is-valid-price price) ERR_INVALID_INPUT)
        
        (let 
            (
                (owner (try! (get-owner character-id)))
            )
            (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
            (map-set market character-id {
                price: price,
                seller: tx-sender
            })
            (ok true)
        )
    )
)

(define-public (buy-character (character-id uint))
    (begin
        ;; Input validation
        (asserts! (is-valid-character-id character-id) ERR_INVALID_INPUT)
        
        (let
            (
                (listing (unwrap! (get-listing character-id) ERR_NOT_FOUND))
                (price (get price listing))
                (seller (get seller listing))
                (buyer-count (get-owner-count tx-sender))
            )
            ;; Additional validation
            (asserts! (< buyer-count MAX_CHARACTERS_PER_USER) ERR_INVALID_INPUT)
            (try! (stx-transfer? price tx-sender seller))
            
            ;; Transfer ownership
            (map-delete market character-id)
            
            (let 
                ((character (unwrap! (get-character character-id) ERR_NOT_FOUND)))
                (map-set characters character-id 
                    (merge character { owner: tx-sender }))
                
                ;; Update ownership counts
                (map-set user-character-count seller 
                    (- (get-owner-count seller) u1))
                (map-set user-character-count tx-sender 
                    (+ buyer-count u1))
                (ok true)
            )
        )
    )
)

(define-public (battle (attacker-id uint) (defender-id uint))
    (begin
        ;; Input validation
        (asserts! (is-valid-character-id attacker-id) ERR_INVALID_INPUT)
        (asserts! (is-valid-character-id defender-id) ERR_INVALID_INPUT)
        (asserts! (not (is-eq attacker-id defender-id)) ERR_INVALID_INPUT)
        
        (let
            (
                (attacker (unwrap! (get-character attacker-id) ERR_NOT_FOUND))
                (defender (unwrap! (get-character defender-id) ERR_NOT_FOUND))
                (current-block block-height)
                (owner (try! (get-owner attacker-id)))
            )
            ;; Verify ownership and cooldown
            (asserts! (is-eq owner tx-sender) ERR_UNAUTHORIZED)
            (asserts! (> current-block (+ (get last-battle-block attacker) u10)) ERR_COOLDOWN)
            
            (let
                (
                    (attack-power (+ (get attack attacker) (get level attacker)))
                    (defense-power (+ (get defense defender) (get level defender)))
                    (attacker-wins (> attack-power defense-power))
                )
                ;; Award XP and potentially level up
                (if attacker-wins
                    (try! (add-xp attacker-id u50))
                    (try! (add-xp defender-id u25))
                )
                
                ;; Update last battle time
                (map-set characters attacker-id 
                    (merge attacker { last-battle-block: current-block }))
                
                (ok attacker-wins)
            )
        )
    )
)

(define-private (add-xp (character-id uint) (xp-amount uint))
    (let
        (
            (character (unwrap! (get-character character-id) ERR_NOT_FOUND))
            (current-xp (get xp character))
            (current-level (get level character))
            (new-xp (+ current-xp xp-amount))
            (xp-required (* BASE_XP_REQUIRED current-level))
        )
        (if (and (>= new-xp xp-required) (< current-level MAX_LEVEL))
            (map-set characters character-id
                (merge character {
                    level: (+ current-level u1),
                    xp: u0,
                    attack: (+ (get attack character) u1),
                    defense: (+ (get defense character) u1)
                }))
            (map-set characters character-id
                (merge character {
                    xp: new-xp
                }))
        )
        (ok true)
    )
)