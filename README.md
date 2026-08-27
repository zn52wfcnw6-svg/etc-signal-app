# ETC永续合约信号监控系统

机构级双周期抓顶抓底信号监控APP，基于Flutter跨平台开发，支持Android/iOS。

## 核心特性

- **双周期策略**：4H/1D长周期划定关键位，1m/5m短周期六闸门确认链精确入场
- **五源行情校验**：Binance/OKX/Bybit/Bitget/Gate五家交易所价格MAD动态交叉校验
- **订单流确认**：CVD背离 + Delta反转 + 流动性清扫，机构级反转确认
- **全局冻结机制**：BTC波动/结构破位/行情异常/账户风险/清算挤压五重冻结
- **自修复监控**：三层健康检查 + 自动降级 + 异常恢复
- **自动迭代引擎**：信号结果跟踪 → 场景化分析 → 受限调参 → 灰度验证 → 自动回滚
- **纯本地运行**：所有数据本地存储，不上传云端，无自动下单

## 项目结构

```
lib/
├── main.dart                          # 应用入口
├── config/
│   └── app_state.dart                 # 全局状态管理
├── models/
│   ├── market_data.dart               # 行情/K线/逐笔/关键位模型
│   ├── signal.dart                    # 交易信号模型
│   └── position.dart                  # 持仓模型
├── data/
│   ├── apis/exchange_api.dart         # 5家交易所API客户端
│   ├── websocket_manager.dart         # WebSocket + 订单流管理
│   ├── market_validator.dart          # MAD交叉校验器
│   └── market_data_manager.dart       # 行情数据统一调度
├── engine/
│   ├── long_cycle/
│   │   ├── structure_analyzer.dart    # BOS/CHoCH市场结构
│   │   ├── key_levels.dart            # 摆动点+VPVR+流动性池关键位
│   │   ├── volatility_oi.dart         # 波动率/OI/资金费率分析
│   │   └── long_cycle_manager.dart    # 长周期状态管理
│   ├── short_cycle/
│   │   ├── signal_detector.dart       # 六闸门确认链+置信度评分
│   │   └── signal_engine.dart         # 信号引擎+生命周期
│   ├── risk/
│   │   └── risk_manager.dart          # 风控+全局冻结状态机
│   └── iteration/
│       ├── backtest_engine.dart       # 回测引擎
│       └── iteration_engine.dart      # 自动迭代引擎
├── monitor/
│   └── self_healing.dart              # 自修复监控层
├── storage/
│   └── database_helper.dart           # SQLite本地数据库
├── screens/
│   ├── home_page.dart                 # 主框架+底部导航
│   ├── signal_panel.dart              # 信号面板
│   ├── positions_page.dart            # 持仓管理
│   ├── history_page.dart              # 历史信号
│   └── settings_page.dart             # 设置页
└── utils/
    ├── constants.dart                 # 系统常量
    └── indicators.dart                # 技术指标库
```

## 信号生成逻辑

### 长周期（4H/1D）
1. SMC市场结构判定（BOS趋势延续 / CHoCH趋势反转）
2. 三层关键位绘制（摆动高低点 + VPVR成交量分布 + 流动性池）
3. 波动率状态（ATR百分位 + 布林带宽度）
4. OI背离 + 资金费率极端度判定
5. 输出：支撑区有效 / 压力区有效 / 中性 / 趋势衰竭

### 短周期（1m/5m）六闸门确认链
| 闸门 | 多头条件 | 空头条件 |
|------|---------|---------|
| G1 位置 | 价格在支撑带内 | 价格在压力带内 |
| G2 流动性清扫 | 下影线刺穿支撑后收回 | 上影线刺穿压力后收回 |
| G3 CVD背离 | 价格创新低CVD不创新低 | 价格创新高CVD不创新高 |
| G4 Delta反转 | 卖盘衰竭买盘递增 | 买盘衰竭卖盘递增 |
| G5 K线形态 | pin bar/看涨吞没/FVG反弹 | pin bar/看跌吞没/FVG回落 |
| G6 持续确认 | 连续3次8秒轮询成立 | 连续3次8秒轮询成立 |

### 置信度评分（0-100）
- 关键位强度（0-30）：三层叠加命中数
- 订单流强度（0-30）：CVD背离幅度 + 双源一致性
- 多周期共振（0-20）：1m/5m同时反转
- 环境清洁度（0-20）：资金费率配合 + BTC稳定

**≥70分输出信号，65-69分记录不告警，<65分丢弃。**

## 全局冻结条件

| 编号 | 条件 | 阈值 |
|------|------|------|
| F1 | BTC短周期波动 | 5m > ±1.8% 或 15m > ±3% |
| F2 | BTC关键结构破位 | 4H CHoCH 或 跌破2个摆动低点 |
| F3 | 行情校验失败 | ≥2家交易所价格异常 |
| F4 | 账户总风险 | ≥5%账户净值 |
| F5 | 清算挤压 | 资金费率极端+OI骤降+主动买卖比极端（三选二） |

## 交易执行规则

- 分批建仓，禁止一次性重仓
- 单笔账户风险 ≤ 1%
- 严格使用APP给出的SL止损位
- TP1减仓60%，止损移至开仓成本
- TP2全部平仓，不达标则止损离场
- 冻结/无信号状态禁止任何开仓

## 自动迭代机制

1. **结果跟踪**：每笔信号记录执行结果和盈亏
2. **场景分析**：按置信度区间/市场状态/时间段分类统计
3. **受限调参**：仅允许调整5个白名单参数，范围和步长受限
4. **灰度验证**：新参数观察模式运行7天，统计显著后切换
5. **自动回滚**：切换后最大回撤超阈值立即回滚
6. **熔断保护**：连续3次回滚后暂停迭代，需人工介入

## 开发环境

- Flutter 3.24.5+
- Dart 3.5.4+
- Android SDK（构建Android）
- Xcode（构建iOS）

## 构建运行

```bash
# 安装依赖
flutter pub get

# 静态分析
flutter analyze

# 运行（需连接设备或模拟器）
flutter run

# 构建APK
flutter build apk --release

# 构建iOS
flutter build ios --release
```

## 免责声明

本APP仅输出行情监控信号，不构成任何投资建议，不集成自动下单功能。加密货币交易风险极高，所有交易决策和风险由使用者自行承担。
