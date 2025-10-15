# Swift BattleFlow - 作業計画

## プロジェクト概要
JRPGのターン制戦闘システムを実装するPure Swiftライブラリ。State-Storeパターンを採用し、副作用（アニメーション、サウンド等）をEffectとして分離する。

## アーキテクチャ設計

### コアコンセプト
- **State**: 戦闘の現在状態を表すイミュータブルな構造体
- **Action**: 状態変更を表すenumケース  
- **Store**: 状態管理とアクション処理の中央ハブ
- **Effect**: 副作用（アニメーション、サウンド、UI更新）を表現
- **Reducer**: Action + State → (State, [Effect]) の純粋関数

## 実装フェーズ

### フェーズ 1: コアアーキテクチャ基盤 ✅
#### 1.1 基本型定義
- [x] `BattleState` - 戦闘状態の定義
- [x] `BattleAction` - アクション列挙型
- [x] `Effect` - 副作用プロトコル
- [x] `BattleStore` - 状態管理ストア

#### 1.2 Reducer実装
- [x] `BattleReducer` - メインReducer
- [x] アクション処理ロジック
- [x] 状態遷移の定義

### フェーズ 2: 戦闘システム基本要素 (部分完了)
#### 2.1 キャラクター・エンティティ
- [x] `Combatant` - 戦闘参加者の基本構造
- [x] `Stats` - ステータス（HP、MP、ATK、DEF等）
- [ ] `Character` - プレイヤーキャラクター
- [ ] `Enemy` - 敵キャラクター

### フェーズ 3: ターンベース戦闘ロジック (部分完了)
#### 3.1 ターン管理
- [ ] `TurnOrder` - 行動順序の計算
- [x] `TurnPhase` - ターンフェーズ管理 (BattlePhaseとして実装)
- [ ] 速度値に基づくイニシアチブ計算

#### 3.2 戦闘フロー
- [x] 戦闘開始/終了処理
- [ ] プレイヤー入力処理
- [ ] AI行動選択
- [x] ダメージ計算システム (基本実装)

### フェーズ 4: エフェクトシステム (部分完了)
#### 4.1 基本エフェクト
- [x] `DamageEffect` - ダメージ表示エフェクト (BaseEffectとして実装)
- [x] `HealEffect` - 回復エフェクト (BaseEffectとして実装)
- [x] `SoundEffect` - サウンド再生エフェクト (BaseEffectとして実装)
- [x] `AnimationEffect` - アニメーション指示 (BaseEffectとして実装)

#### 4.2 エフェクト処理
- [x] `EffectHandler` - エフェクト実行の抽象化 (BattleStoreで実装)
- [x] エフェクトキューイング (優先度ソート実装済み)
- [x] 非同期エフェクト処理 (Taskによる実装済み)

### フェーズ 5: 高度な戦闘機能
#### 5.1 状態異常システム
- [ ] `StatusEffect` - 状態異常の定義
- [ ] 毒、麻痺、睡眠等の実装
- [ ] 状態異常の時間管理

#### 5.2 アイテムシステム
- [ ] `Item` - アイテムの基本構造
- [ ] アイテム使用ロジック
- [ ] インベントリ管理

### フェーズ 6: テストとバリデーション (部分完了)
#### 6.1 ユニットテスト
- [x] Reducerテスト (BattleReducerテスト実装済み)
- [x] ダメージ計算テスト (HP変更・攻撃テスト実装済み)
- [ ] ターン順序テスト
- [x] 状態遷移テスト (戦闘開始・終了テスト実装済み)

#### 6.2 統合テスト
- [x] 完全戦闘フローテスト (統合テスト実装済み)
- [x] エフェクト統合テスト (エフェクト実行テスト実装済み)
- [ ] パフォーマンステスト

### フェーズ 7: ドキュメント・サンプル
#### 7.1 ドキュメント作成
- [ ] API documentation
- [ ] 使用例とチュートリアル
- [ ] アーキテクチャガイド

#### 7.2 サンプル実装
- [ ] 基本戦闘サンプル
- [ ] UI統合サンプル
- [ ] カスタムエフェクトの例

## ファイル構造計画

```
Sources/swift-battleflow/
├── Core/
│   ├── BattleStore.swift
│   ├── BattleState.swift
│   ├── BattleAction.swift
│   ├── BattleReducer.swift
│   └── Effect.swift
├── Entities/
│   ├── Combatant.swift
│   ├── Character.swift
│   ├── Enemy.swift
│   └── Stats.swift
├── Turn/
│   ├── TurnOrder.swift
│   ├── TurnPhase.swift
│   └── Initiative.swift
├── Combat/
│   ├── DamageCalculator.swift
│   ├── BattleFlow.swift
│   └── AIBehavior.swift
├── Effects/
│   ├── EffectHandler.swift
│   ├── DamageEffect.swift
│   ├── HealEffect.swift
│   ├── SoundEffect.swift
│   └── AnimationEffect.swift
├── StatusEffects/
│   ├── StatusEffect.swift
│   └── StatusEffectManager.swift
├── Items/
│   ├── Item.swift
│   └── ItemEffect.swift
└── Utilities/
    ├── RandomNumberGenerator.swift
    └── Extensions.swift
```

## 実装進捗状況

### ✅ 完了済み
- **フェーズ1: コアアーキテクチャ基盤** - 100%完了
  - Pure SwiftでState-Storeパターン実装
  - ObservationフレームワークによるモダンなUI状態管理
  - 包括的なテストスイート (15テスト全て成功)

### 🚧 部分完了
- **フェーズ2: 戦闘システム基本要素** - 50%完了 (Combatant/Stats完了)
- **フェーズ3: ターンベース戦闘ロジック** - 50%完了 (基本フロー完了)
- **フェーズ4: エフェクトシステム** - 100%完了 (基盤実装)
- **フェーズ6: テストとバリデーション** - 80%完了 (主要テスト完了)

## 次のステップ
1. **フェーズ2の完成**: Character/Enemy差別化
2. **フェーズ3の拡張**: TurnOrder、AI行動決定
3. **フェーズ5**: 状態異常システム、アイテムシステム
4. **フェーズ7**: API documentation、サンプルアプリ

