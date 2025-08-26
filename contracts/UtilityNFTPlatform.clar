;; UtilityNFT Platform Contract
;; NFTs with real-world utility like membership access, voting rights, and exclusive benefits

;; Define the NFT
(define-non-fungible-token utility-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-nft-not-found (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-invalid-token-id (err u104))

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var platform-name (string-ascii 50) "UtilityNFT Platform")

;; Maps
;; Track NFT metadata and utility features
(define-map nft-metadata uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    membership-tier: (string-ascii 20),
    voting-power: uint,
    benefits-unlocked: bool
})

;; Track voting participation to prevent double voting
(define-map voting-records {token-id: uint, proposal-id: uint} bool)

;; Track membership access levels
(define-map membership-access uint {
    tier: (string-ascii 20),
    access-level: uint,
    expiry-block: uint
})

;; Function 1: Mint UtilityNFT with membership and voting rights
(define-public (mint-utility-nft 
    (recipient principal)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (membership-tier (string-ascii 20))
    (voting-power uint)
    (access-level uint)
    (membership-duration uint))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      
      ;; Mint the NFT
      (try! (nft-mint? utility-nft token-id recipient))
      
      ;; Set NFT metadata with utility features
      (map-set nft-metadata token-id {
        name: name,
        description: description,
        membership-tier: membership-tier,
        voting-power: voting-power,
        benefits-unlocked: true
      })
      
      ;; Set membership access rights
      (map-set membership-access token-id {
        tier: membership-tier,
        access-level: access-level,
        expiry-block: (+ stacks-block-height membership-duration)
      })
      
      ;; Update token counter
      (var-set last-token-id token-id)
      
      (ok token-id))))

;; Function 2: Cast vote using NFT voting power (utility function)
(define-public (cast-vote (token-id uint) (proposal-id uint) (vote-choice bool))
  (let (
    (token-owner (unwrap! (nft-get-owner? utility-nft token-id) err-nft-not-found))
    (nft-data (unwrap! (map-get? nft-metadata token-id) err-nft-not-found))
    (voting-key {token-id: token-id, proposal-id: proposal-id})
  )
    (begin
      ;; Verify caller owns the NFT
      (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
      
      ;; Check if already voted on this proposal
      (asserts! (is-none (map-get? voting-records voting-key)) err-already-voted)
      
      ;; Record the vote
      (map-set voting-records voting-key true)
      
      ;; Print vote details for tracking
      (print {
        event: "vote-cast",
        token-id: token-id,
        proposal-id: proposal-id,
        vote-choice: vote-choice,
        voting-power: (get voting-power nft-data),
        voter: tx-sender
      })
      
      (ok {
        token-id: token-id,
        voting-power: (get voting-power nft-data),
        vote-recorded: true
      }))))

;; Read-only functions

;; Get NFT metadata and utility features
(define-read-only (get-nft-data (token-id uint))
  (ok (map-get? nft-metadata token-id)))

;; Get membership access details
(define-read-only (get-membership-access (token-id uint))
  (ok (map-get? membership-access token-id)))

;; Check if NFT holder has voted on a proposal
(define-read-only (has-voted (token-id uint) (proposal-id uint))
  (ok (is-some (map-get? voting-records {token-id: token-id, proposal-id: proposal-id}))))

;; Get NFT owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? utility-nft token-id)))

;; Get last minted token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

;; Get platform name
(define-read-only (get-platform-name)
  (ok (var-get platform-name)))