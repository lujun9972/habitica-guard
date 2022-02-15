#!/bin/sh
":"; exec emacs --quick --script "$0" -- "$@" # -*- mode: emacs-lisp; lexical-binding: t; -*-

(require 'cl-lib)
(setq network-security-level 'low)
;; habitica健康检查
(setq workplace (getenv "GITHUB_WORKSPACE"))
(load (expand-file-name "emacs-habitica/habitica.el" workplace))
(habitica-tasks)
(message "Habitica:HP:%s,GOLD:%S,Class" habitica-hp habitica-gold habitica-class)

(defun habitica-auto-run-cron ()
  "自动运行cron"
  (habitica-cron))

(defun habitica-auto-recover-by-potion ()
  "通过药剂回血"
  (while (< habitica-hp (- habitica-max-hp 10))
    (habitica-buy-health-potion)))

(defun habitica-auto-recover-by-skill ()
  "通过治疗技能回血"
  (while (and  (< habitica-hp (- habitica-max-hp 10))
               (> habitica-mp 25))
    (let* ((result (habitica-api-cast-skill "healAll"))
           (party-members (cdr (assoc-string "partyMembers" result)))
           (me (elt party-members 0))
           (my-stats (cdr (assoc-string "stats" me))))
      (habitica--set-profile my-stats))))

(defun habitica-auto-accept-party-quest ()
  "自动接受 party quest"
  (habitica-accept-party-quest))


(defun habitica-auto-allocate-stat-point ()
  "自动分配属性点"
  (let* ((stat (getenv "HABITICA_ALLOCATE_STAT"))
         (remain-points (habitica-allocate-a-stat-point)))
    (while (and remain-points
                (> remain-points 0))
      (setq remain-points (habitica-allocate-a-stat-point)))))

(defun habitica-auto-buy-armoire ()
  "自动抽奖"
  (let* ((habitica-keep-gold (or (getenv "HABITICA-KEEP-GOLD")
                                 "1000"))
         (habitica-keep-gold (string-to-number habitica-keep-gold)))
    (while (and (> habitica-keep-gold 0)
                (> habitica-gold habitica-keep-gold)
                (> habitica-gold 100))
      (habitica-api-buy-armoire)
      (setq habitica-gold (- habitica-gold 100)))))

(defun habitica-auto-buy-inventory ()
  "自动购买装备"
  (let* ((assoc-key-fn (apply-partially #'assoc-default 'key))
         (inventory-data (habitica--send-request "/user/inventory/buy" "GET" ""))
         (inventory-keys (mapcar assoc-key-fn inventory-data))
         (reward-data (habitica--send-request "/user/in-app-rewards" "GET" ""))
         (buy-fn (lambda (key)
                   (habitica--send-request (format "/user/buy/%s" key) "POST" ""))))
    (mapc buy-fn inventory-keys)))

(ignore-errors
  (habitica-auto-run-cron)
  (when (string= habitica-class "healer")
    (habitica-auto-recover-by-skill))
  (habitica-auto-recover-by-potion)
  (habitica-auto-buy-armoire)
  (habitica-auto-accept-party-quest)
  (habitica-auto-allocate-stat-point)
  (habitica-auto-buy-inventory))
