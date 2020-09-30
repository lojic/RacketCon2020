#lang racket/base

(require "./axio-database.rkt"
         "./axio-env.rkt"
         "./axio-init-structs.rkt"
         "./axio-logger.rkt")

(require db
         racket/contract)

(provide axio-init)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define/contract (axio-init app-env-id #:log-level [ log-level 'warning ])
  (->* (symbol?) (#:log-level symbol?) axio-context?)

  (axio-init-logger log-level)

  (axio-context
   app-env-id
   (axio-init-db (get-app-env app-env-id))))

;; --------------------------------------------------------------------------------------------
;; Private Implementation
;; --------------------------------------------------------------------------------------------

;; (axio-init-db app-env-obj) -> axio-db-context?
;; app-env-obj : app-env?
(define (axio-init-db app-env-obj)
  (virtual-connection
   (connection-pool (λ () (db-connect app-env-obj))
                    #:max-connections 30
                    #:max-idle-connections 4)))
