# swift-battleflow
BattleFlow is a pure Swift battle engine built around State -> Action -> State.

The engine layer is rule-agnostic. The bundled JRPG rule set lives separately as
`JRPGBattleFlow`, `JRPGBattleState`, `JRPGAction`, `JRPGReducer`, and
`JRPGBattleStore`.
