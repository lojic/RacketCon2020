#lang racket

(provide (struct-out webctx))

(struct webctx (request
                attributes
                session
                connection
                axioctx
                user)
        #:transparent)
