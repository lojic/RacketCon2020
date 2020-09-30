#lang racket/base

;; See ./axio/axio-env.rkt for environment settings
;; See ./router.rkt & ./url-generator.rkt for routing

(module+ main
  (require "./axio/axio-app.rkt"
           "./models/user.rkt"
           "./router.rkt")
  (axio-app-init 'production route read-user))
