-- 每日对账：储备资产市值 vs 流通稳定币面值
-- 对应《稳定币条例》的 full backing（全额支持）要求

-- 第一步：把每天的储备持仓按日期汇总成一个市值
with reserve as (
    select
        date,
        sum(market_value) as reserve_value
    from {{ ref('reserve_holdings') }}
    group by date
),
-- 第二步：取出每天流通的稳定币面值
circulation as (
    select * from {{ ref('daily_circulation') }}
)

-- 第三步：两边按日期对齐，算差额，判断是否全额支持
select
    c.date,
    c.par_value,
    r.reserve_value,
    r.reserve_value - c.par_value as buffer,   -- 超额多少（正数 = 有缓冲）
    case
        when r.reserve_value >= c.par_value then true
        else false
    end as is_fully_backed                      -- 是否满足全额支持
from circulation c
left join reserve r on c.date = r.date
