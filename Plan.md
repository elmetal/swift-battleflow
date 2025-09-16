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

### フェーズ 1: コアアーキテクチャ基盤
#### 1.1 基本型定義
- [ ] `BattleState` - 戦闘状態の定義
- [ ] `BattleAction` - アクション列挙型
- [ ] `Effect` - 副作用プロトコル
- [ ] `BattleStore` - 状態管理ストア

#### 1.2 Reducer実装
- [ ] `BattleReducer` - メインReducer
- [ ] アクション処理ロジック
- [ ] 状態遷移の定義

### フェーズ 2: 戦闘システム基本要素
#### 2.1 キャラクター・エンティティ
- [ ] `Combatant` - 戦闘参加者の基本構造
- [ ] `Stats` - ステータス（HP、MP、ATK、DEF等）
- [ ] `Character` - プレイヤーキャラクター
- [ ] `Enemy` - 敵キャラクター

#### 2.2 スキル・アビリティシステム
- [ ] `Skill` - スキル/技の定義
- [ ] `SkillEffect` - スキル効果の計算
- [ ] `TargetSelector` - ターゲット選択ロジック

### フェーズ 3: ターンベース戦闘ロジック
#### 3.1 ターン管理
- [ ] `TurnOrder` - 行動順序の計算
- [ ] `TurnPhase` - ターンフェーズ管理
- [ ] 速度値に基づくイニシアチブ計算

#### 3.2 戦闘フロー
- [ ] 戦闘開始/終了処理
- [ ] プレイヤー入力処理
- [ ] AI行動選択
- [ ] ダメージ計算システム

### フェーズ 4: エフェクトシステム
#### 4.1 基本エフェクト
- [ ] `DamageEffect` - ダメージ表示エフェクト
- [ ] `HealEffect` - 回復エフェクト
- [ ] `SoundEffect` - サウンド再生エフェクト
- [ ] `AnimationEffect` - アニメーション指示

#### 4.2 エフェクト処理
- [ ] `EffectHandler` - エフェクト実行の抽象化
- [ ] エフェクトキューイング
- [ ] 非同期エフェクト処理

### フェーズ 5: 高度な戦闘機能
#### 5.1 状態異常システム
- [ ] `StatusEffect` - 状態異常の定義
- [ ] 毒、麻痺、睡眠等の実装
- [ ] 状態異常の時間管理

#### 5.2 アイテムシステム
- [ ] `Item` - アイテムの基本構造
- [ ] アイテム使用ロジック
- [ ] インベントリ管理

### フェーズ 6: テストとバリデーション
#### 6.1 ユニットテスト
- [ ] Reducerテスト
- [ ] ダメージ計算テスト
- [ ] ターン順序テスト
- [ ] 状態遷移テスト

#### 6.2 統合テスト
- [ ] 完全戦闘フローテスト
- [ ] エフェクト統合テスト
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
├── Skills/
│   ├── Skill.swift
│   ├── SkillEffect.swift
│   └── TargetSelector.swift
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

## 次のステップ
1. フェーズ1のコアアーキテクチャから開始
2. 各フェーズ完了後にレビュー・調整
3. 継続的なテスト・ドキュメント更新
4. コミュニティフィードバックの収集と反映

