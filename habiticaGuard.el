#!/bin/sh
":"; exec emacs --quick --script "$0" -- "$@" # -*- mode: emacs-lisp; lexical-binding: t; -*-

(require 'cl-lib)
(setq debug-on-error t)
(setq network-security-level 'low)
;; habitica健康检查
(setq workplace (getenv "GITHUB_WORKSPACE"))
(load (expand-file-name "emacs-habitica/habitica.el" workplace))
(habitica-tasks)
(message "Habitica:HP:%s,GOLD:%s,Class %s" habitica-hp habitica-gold habitica-class)

(defun habitica-auto-run-cron ()
  "自动运行cron"
  (when (habitica-api-need-cron-p)
    (message "自动运行 cron")
    (habitica-api-cron)
    (message "自动施展增益魔法")
    ;; HABITICA_DAILY_SKILLS的格式为"SKILL[ TARGET_ID];SKILL[ TARGET_ID]" 
    (let* ((skills (split-string (getenv "HABITICA_DAILY_SKILLS") ";"))
           (skill-target-list (mapcar #'split-string skills)))
      (mapc (lambda (skill-target)
              (apply #'habitica-api-cast-skill skill-target))
            skill-target-list))))

(defun habitica-auto-recover-by-potion ()
  "通过药剂回血"
  (while (< habitica-hp (- habitica-max-hp 10))
    (message "need to buy health-potion")
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
         (remain-points (habitica-allocate-a-stat-point stat)))
    (message "剩余点数： %s" remain-points)
    (while (and remain-points
                (> remain-points 0))
      (message "分配点数到： %s" stat)
      (setq remain-points (habitica-allocate-a-stat-point stat)))))

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
                          (currency (or (assoc-default 'currency the-item)
                                        "gold"))
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

(message "自动运行cron, 并施展增益技能")
(habitica-auto-run-cron)
(message "自动加血")
(when (string= habitica-class "healer")
  (habitica-auto-recover-by-skill))
(habitica-auto-recover-by-potion)
(message "自动买宝箱")
(habitica-auto-buy-armoire)
(message "自动接受party 任务")
(habitica-auto-accept-party-quest)
(message "自动分配属性点")
(habitica-auto-allocate-stat-point)
(message "自动买装备")
(habitica-auto-buy-inventory)
