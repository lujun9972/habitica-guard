#!/bin/sh
":"; exec emacs --quick --script "$0" -- "$@" # -*- mode: emacs-lisp; lexical-binding: t; -*-

(require 'cl-lib)
(setq network-security-level 'low)
;; habitica健康检查
(setq workplace (getenv "GITHUB_WORKSPACE"))
(load (expand-file-name "emacs-habitica/habitica.el" workplace))
(habitica-tasks)
(message "Habitica:HP:%s,GOLD:%S,Class" habitica-hp habitica-gold habitica-class)

(defun habitica-api-need-cron-p ()
  "Need to run cron or not."
  (let ((needsCron (assoc-default 'needsCron (habitica-api-get-profile))))
    (message "needsCron=%s" needsCron)
    (equal needsCron t)))

(defun habitica-update-stats (stats)
  (setq habitica-mp (cdr (assoc-string "mp" stats)))
  (setq habitica-hp (cdr (assoc-string "hp" stats)))
  (setq habitica-gold (cdr (assoc-string "gp" stats))))

(defun habitica-auto-run-cron ()
  "自动运行cron"
  (when (habitica-api-need-cron-p)
    (habitica-cron)))

(defun habitica-auto-recover-by-potion ()
  "通过药剂回血"
  (while (and  (< habitica-hp (- habitica-max-hp 10))
               (> habitica-gold 15))
    (let ((stats (habitica--send-request "/user/buy-health-potion" "POST" "")))
      (habitica-update-stats stats))))

(defun habitica-auto-recover-by-skill ()
  "通过治疗技能回血"
  (while (and  (< habitica-hp (- habitica-max-hp 10))
               (> habitica-mp 25))
    (let* ((result (habitica-api-cast-skill "healAll"))
           (party-members (cdr (assoc-string "partyMembers" result)))
           (me (elt party-members 0))
           (my-stats (cdr (assoc-string "stats" me))))
      (habitica-update-stats my-stats))))

(defun habitica-auto-accept-party-quest ()
  "自动接受 party quest"
  (let* ((user-data (habitica--send-request (format "/user?userFields=party") "GET" ""))
         (party-data (assoc-default 'party user-data))
         (quest-data (assoc-default 'quest party-data))
         (completed-data (assoc-default 'completed quest-data))
         (RSVPNeeded (assoc-default 'RSVPNeeded quest-data)))
    (message "party-data:%s" party-data)
    (message "quest-data:%s" quest-data)
    (message "completed-data:%s" completed-data)
    (message "RSVPNeeded-data:%s" RSVPNeeded)
    (when (equal RSVPNeeded t)
      (habitica--send-request (format "/groups/party/quests/accept") "POST" ""))))

(habitica--send-request (format "/user") "GET" "")

(defun habitica-auto-allocate-stat-point ()
  "自动分配属性点"
  (let* ((stat (getenv "HABITICA_ALLOCATE_STAT"))
         (valid-stats '("str" "con" "int" "per"))
         (user-data (habitica--send-request (format "/user?userFields=stats") "GET" ""))
         (stats-data (assoc-default 'stats user-data))
         (points (assoc-default 'points stats-data))
         (flags-data (assoc-default 'flags user-data))
         (classSelected (assoc-default 'classSelected flags-data)))
    (message "remain %s points,allocate %s point" points stat)
    (while (and (equal classSelected t)
                (> points 0)
                (member stat valid-stats))
      (habitica--send-request (format "/user/allocate?stat=%s" stat) "POST" "")
      (setq points (- points 1)))))

(defun habitica-auto-buy-armoire ()
  "自动抽奖"
  (let* ((habitica-keep-gold (or (getenv "HABITICA-KEEP-GOLD")
                                 "1000"))
         (habitica-keep-gold (string-to-number habitica-keep-gold)))
    (while (and (> habitica-keep-gold 0)
                (> habitica-gold habitica-keep-gold))
      (habitica--send-request "/user/buy-armoire" "POST" "")
      (setq habitica-gold (- habitica-gold 100)))))

(defun habitica-auto--buy-item-from (items-data)
  "自动购买 ITEMS-DATA 中的 item"
  (let* ((assoc-key-fn (apply-partially #'assoc-default 'key))
         (item-keys (mapcar assoc-key-fn items-data))
         (buy-fn (lambda (key)
                   (let* ((the-item (cl-find-if
                                     (lambda (item)
                                       (equal key (funcall assoc-key-fn item)))
                                     items-data))
                          (pinned (assoc-default 'pinned the-item))
                          (currency (assoc-default 'currency the-item))
                          (value (assoc-default 'value the-item)))
                     (message "key:%s,pinned:%s,currency:%s,value:%s" key pinned currency value)
                     (when (and (not pinned)
                                (string= currency "gold")
                                (< value habitica-gold))
                       (message "Buy %s using %s %ss" key value currency)
                       (habitica--send-request (format "/user/buy/%s" key) "POST" "")
                       (setq habitica-gold (- habitica-gold value)))))))
    (mapc buy-fn item-keys)))

(defun habitica-auto-buy-inventory ()
  "自动购买装备"
  (let* ((inventory-data (habitica--send-request "/user/inventory/buy" "GET" ""))
         (reward-data (habitica--send-request "/user/in-app-rewards" "GET" "")))
    (habitica-auto--buy-item-from inventory-data)
    (habitica-auto--buy-item-from reward-data)))

(ignore-errors
  (habitica-auto-run-cron)
  (when (string= habitica-class "healer")
    (habitica-auto-recover-by-skill))
  (habitica-auto-recover-by-potion)
  (habitica-auto-buy-armoire)
  (habitica-auto-accept-party-quest)
  (habitica-auto-allocate-stat-point)
  (habitica-auto-buy-inventory))
