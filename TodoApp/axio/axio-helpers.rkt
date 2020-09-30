#lang racket/base

(require "./axio-web-ctx.rkt")

(provide get-current-user)

;; --------------------------------------------------------------------------------------------
;; Public Interface
;; --------------------------------------------------------------------------------------------

(define (get-current-user ctx)
  (webctx-user ctx))
