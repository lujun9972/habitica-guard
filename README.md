# habitica-guard
habitica自动补血（接任务、购物等其他操作）

## 功能
+ 自动补血
+ 自动购买宝箱
+ 自动接party任务

## 使用
### 配置环境变量
Settings -> Secrets -> Actions -> New repository secret
[点击这里](../../settings/secrets/actions/new)

配置
+ `HABITICA_TOKEN`: API令牌
+ `HABITICA_UUID`: 用户ID
+ `HABITICA_KEEP_GOLD`: 保留的金币数，多于这个金币则会去购买宝箱(负数不会去购买宝箱)
+ `HABITICA_ALLOCATE_STAT`: 点数分配到哪个属性，可选值为 `str`, `con`, `int`, `per`。其他值或留空不会自动分配点数
+ `HABITICA_DAILY_SKILLS`: 每日使用的增益魔法，为空则不自动使用增益魔法. `HABITICA_DAILY_SKILLS` 的格式为`SKILL[ TARGET_ID];SKILL[ TARGET_ID]` 

## 技能关键字与名字的对应关系

+ Mage: fireball="Burst of Flames", mpheal="Ethereal Surge", earth="Earthquake", frost="Chilling Frost"

+ Warrior: smash="Brutal Smash", defensiveStance="Defensive Stance", valorousPresence="Valorous Presence", intimidate="Intimidating Gaze"

+ Rogue: pickPocket="Pickpocket", backStab="Backstab", toolsOfTrade="Tools of the Trade", stealth="Stealth"

+ Healer: heal="Healing Light", protectAura="Protective Aura", brightness="Searing Brightness", healAll="Blessing"

+ Transformation Items: snowball="Snowball", spookySparkles="Spooky Sparkles", seafoam="Seafoam", shinySeed="Shiny Seed"
