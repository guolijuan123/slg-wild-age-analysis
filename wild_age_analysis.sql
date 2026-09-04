-- 项目：野蛮时代手游新注册用户首周行为分析
-- 数据集：jushuyunhai_other 游戏业务库
-- 内容：注册统计、用户分层、消费、玩法相关全部查询脚本
-- 2018‑03注册用户，样本828934条

/*一、注册分析*/

-- 1.1每日情况
SELECT DATE_FORMAT(register_time,"%Y年%m月%d日") 注册日期,
        case when WEEKDAY(register_time)=0 then "星期一"
             when WEEKDAY(register_time)=1 then "星期二"
             when WEEKDAY(register_time)=2 then "星期三"
             when WEEKDAY(register_time)=3 then "星期四"
             when WEEKDAY(register_time)=4 then "星期五"
             when WEEKDAY(register_time)=5 then "星期六"
             else "星期日"
             end 星期几, 
             count(*) 注册人数
FROM tap_fun
group by 注册日期
ORDER BY 注册日期 asc;

-- 1.2小时注册情况
SELECT DATE_FORMAT(register_time,"%H") 注册小时,
             count(*) 注册人数
FROM tap_fun
group by 注册小时
ORDER BY 注册小时 asc;

/*二、用户质量分析*/
-- 2.1汇总：注册-活跃-付费(定义平均每日在线时长20分钟以上的用户为活跃用户)
SELECT count(*) 注册人数,
       sum(if(avg_online_minutes>20,1,0)) 活跃人数,
       sum(if(pay_price>0,1,0)) 付费人数,
       sum(if(avg_online_minutes>20,1,0))/count(*) 活跃人数占比,
       sum(if(pay_price>0,1,0))/count(*) 整体付费转化率,
       sum(if(pay_price>0,1,0))/sum(if(avg_online_minutes>20,1,0)) 付费占活跃用户,
       sum(pay_price) 付费总金额,
       sum(pay_count) 付费总次数,
       sum(pay_price)/sum(if(avg_online_minutes>20,1,0)) ARPU,
       sum(pay_price)/sum(if(pay_price>0,1,0)) ARPPU,
       sum(pay_price)/sum(if(pay_price>0,1,0)) 付费玩家人均付费金额,
       sum(pay_count)/sum(if(pay_price>0,1,0)) 付费玩家人均付费次数,
       sum(pay_price)/sum(pay_count) 单次平均充值金额
FROM tap_fun;

-- 2.2 升级维度：不同要塞等级维度下活跃与付费数据
SELECT bd_stronghold_level 要塞等级,count(*) 总用户数,
       sum(if(avg_online_minutes>20,1,0)) 活跃人数,
       sum(if(pay_price>0,1,0)) 付费人数,
       sum(if(avg_online_minutes>20,1,0))/count(*) 活跃人数占比,
       sum(if(pay_price>0,1,0))/count(*) 整体付费转化率,
       sum(if(pay_price>0,1,0))/sum(if(avg_online_minutes>20,1,0)) 付费占活跃用户,
       sum(pay_price) 付费总金额,
       sum(pay_count) 付费总次数,
       sum(pay_price)/sum(if(avg_online_minutes>20,1,0)) ARPU,
       sum(pay_price)/sum(if(pay_price>0,1,0)) ARPPU,
       sum(pay_price)/sum(if(pay_price>0,1,0)) 付费玩家人均付费金额,
       sum(pay_count)/sum(if(pay_price>0,1,0)) 付费玩家人均付费次数,
       sum(pay_price)/sum(pay_count) 单次平均充值金额,
       sum(if(avg_online_minutes>20,avg_online_minutes,0))/sum(if(avg_online_minutes>20,1,0)) 平均活跃在线时长
FROM tap_fun
GROUP BY 要塞等级
ORDER BY 要塞等级 asc;

/*三、用户消费分析——按不同付费层级分类*/
-- 3.1活跃/付费总览
with t1 as(SELECT user_id,avg_online_minutes,
                   pay_price,pay_count,
                   bd_stronghold_level,
                   sum(pay_price) over(ORDER BY pay_price desc) 累计销售额
            FROM tap_fun)
SELECT case when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.8 and pay_price>0 then "鲸鱼玩家"
            when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.9 and pay_price>0 then "海豚玩家"
            when pay_price>0 then "小鱼玩家"
            else "0氪玩家"
       end 玩家标签,
       count(*) 总用户数,
       sum(if(avg_online_minutes>20,1,0)) 活跃人数,
       sum(if(avg_online_minutes>20,1,0))/count(*) 活跃人数占比,
       sum(pay_price) 付费总金额,
       sum(pay_count) 付费总次数,
       sum(pay_price)/count(*) 人均付费金额,
       sum(pay_count)/count(*) 人均付费次数,
       if(sum(pay_count)=0,0,sum(pay_price)/sum(pay_count)) 单次平均充值金额,
       avg(avg_online_minutes) 平均在线时长,
       avg(bd_stronghold_level) 平均建筑等级,
       sum(if(avg_online_minutes>20,avg_online_minutes,0))/sum(if(avg_online_minutes>20,1,0)) 平均活跃在线时长 
FROM t1
GROUP BY 玩家标签;

-- 3.2活跃玩家消费偏向
with t1 as(SELECT user_id,avg_online_minutes,
                   pay_price,pay_count,
                   wood_reduce_value 资源_木头,stone_reduce_value 资源_石头,ivory_reduce_value 资源_象牙,
                   meat_reduce_value 资源_肉,magic_reduce_value 资源_魔法,
                   infantry_reduce_value+wound_infantry_reduce_value 兵力_勇士,
                   cavalry_reduce_value+wound_cavalry_reduce_value 兵力_驯兽师,
                   shaman_reduce_value+wound_shaman_reduce_value 兵力_萨满,
                   general_acceleration_reduce_value 加速券_通用,
                   building_acceleration_reduce_value 加速券_建筑,
                   reaserch_acceleration_reduce_value 加速券_科研,
                   training_acceleration_reduce_value 加速券_训练,
                   treatment_acceleration_reduce_value 加速券_治疗,
                   sum(pay_price) over(ORDER BY pay_price desc) 累计销售额
            FROM tap_fun
            WHERE avg_online_minutes>20)
SELECT case when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.8 and pay_price>0 then "鲸鱼玩家"
            when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.9 and pay_price>0 then "海豚玩家"
            when pay_price>0 then "小鱼玩家"
            else "0氪玩家"
       end 玩家标签,
       count(*) 活跃用户数,
       avg(资源_木头+资源_石头+资源_象牙+资源_肉+资源_魔法) 人均资源使用量,
       avg(兵力_勇士+兵力_驯兽师+兵力_萨满) 人均兵力使用量,
       avg(加速券_通用+加速券_建筑+加速券_科研+加速券_训练+加速券_治疗) 人均加速券使用量,
       avg(资源_木头) 木头,avg(资源_石头) 石头,avg(资源_象牙) 象牙,avg(资源_肉) 肉,avg(资源_魔法) 魔法,
       avg(兵力_勇士) 勇士,avg(兵力_驯兽师) 驯兽师,avg(兵力_萨满) 萨满,
       avg(加速券_通用) 通用,avg(加速券_建筑) 建筑,avg(加速券_科研) 科研,avg(加速券_训练) 训练,avg(加速券_治疗) 治疗,
       if(sum(pay_count)=0,0,sum(pay_price)/sum(pay_count)) 平均单次充值金额
FROM t1
GROUP BY 玩家标签;

/*四、玩法偏好*/
#总渗透率——玩家更倾向于PVE玩法
SELECT sum(if(pvp_battle_count>0,1,0))/count(*) PVP渗透率,
       sum(if(pve_battle_count>0,1,0))/count(*) PVE渗透率
FROM tap_fun;

#不同消费层级的活跃玩家玩法偏向及胜率
with t1 as(SELECT user_id,avg_online_minutes,
                   pay_price,pay_count,
                   pvp_battle_count,pvp_lanch_count,pvp_win_count,
                   pve_battle_count,pve_lanch_count,pve_win_count,
                   sum(pay_price) over(ORDER BY pay_price desc) 累计销售额
            FROM tap_fun
            WHERE avg_online_minutes>20)
SELECT case when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.8 and pay_price>0 then "鲸鱼玩家"
            when 累计销售额/(SELECT sum(pay_price) FROM tap_fun)<=0.9 and pay_price>0 then "海豚玩家"
            when pay_price>0 then "小鱼玩家"
            else "0氪玩家"
       end 玩家标签,
       count(*) 活跃用户数,
       avg(pvp_battle_count) 平均PVP次数,avg(pvp_lanch_count) 平均主动PVP次数,
       sum(pvp_win_count)/sum(pvp_battle_count) 平均PVP胜率,
       avg(pve_battle_count) 平均PVE次数,avg(pve_lanch_count) 平均主动PVE次数,
       sum(pve_win_count)/sum(pve_battle_count) 平均PVE胜率
FROM t1
GROUP BY 玩家标签;
-- 氪金对PVE胜率影响不大，对PVP胜率影响较大，普通玩家难以战胜付费玩家，容易导致用户流失

