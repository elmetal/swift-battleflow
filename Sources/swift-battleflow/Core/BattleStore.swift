import Foundation
import Observation

/// State-Storeパターンの中央ハブ
/// 戦闘状態の管理とアクション処理を担当する
@Observable
@MainActor
public final class BattleStore {
    
    /// 現在の戦闘状態
    public private(set) var state: BattleState
    
    /// エフェクトハンドラー（副作用の実行を委譲）
    public var effectHandler: ((any Effect) async -> Void)?
    
    /// Reducer（状態遷移のロジック）
    private let reducer: BattleReducer
    
    /// アクションの履歴（デバッグ用）
    private var actionHistory: [BattleAction] = []
    
    /// 初期化
    /// - Parameter initialState: 初期戦闘状態
    public init(initialState: BattleState = BattleState()) {
        self.state = initialState
        self.reducer = BattleReducer()
    }
    
    /// アクションを実行する
    /// - Parameter action: 実行するアクション
    public func dispatch(_ action: BattleAction) {
        // アクション履歴に追加
        actionHistory.append(action)
        
        // Reducerで状態とエフェクトを計算
        let (newState, effects) = reducer.reduce(state: state, action: action)
        
        // 状態を更新
        state = newState
        
        // エフェクトを実行
        Task {
            await executeEffects(effects)
        }
    }
    
    /// 複数のアクションを順次実行する
    /// - Parameter actions: 実行するアクション配列
    public func dispatch(_ actions: [BattleAction]) {
        for action in actions {
            dispatch(action)
        }
    }
    
    /// 非同期でアクションを実行する
    /// - Parameter action: 実行するアクション
    public func dispatchAsync(_ action: BattleAction) async {
        dispatch(action)
    }
    
    /// 状態をリセットする
    /// - Parameter newState: 新しい状態（nilの場合は初期状態）
    public func resetState(_ newState: BattleState? = nil) {
        state = newState ?? BattleState()
        actionHistory.removeAll()
    }
    
    /// アクション履歴を取得する
    /// - Returns: 実行されたアクションの配列
    public func getActionHistory() -> [BattleAction] {
        return actionHistory
    }
    
    /// アクション履歴をクリアする
    public func clearActionHistory() {
        actionHistory.removeAll()
    }
    
    /// 現在の状態のスナップショットを取得する
    /// - Returns: 現在の戦闘状態のコピー
    public func getStateSnapshot() -> BattleState {
        return state
    }
}

// MARK: - エフェクト処理

extension BattleStore {
    
    /// エフェクトを実行する
    /// - Parameter effects: 実行するエフェクト配列
    private func executeEffects(_ effects: [any Effect]) async {
        // 優先度でソート（高い順）
        let sortedEffects = effects.sorted { $0.priority > $1.priority }
        
        for effect in sortedEffects {
            await executeEffect(effect)
        }
    }
    
    /// 単一のエフェクトを実行する
    /// - Parameter effect: 実行するエフェクト
    private func executeEffect(_ effect: any Effect) async {
        // エフェクトハンドラーが設定されている場合は委譲
        if let handler = effectHandler {
            await handler(effect)
        } else {
            // デフォルトの処理（ログ出力のみ）
            print("🎬 Effect executed: \(effect.id) (priority: \(effect.priority))")
        }
        
        // エフェクト実行のアクションをディスパッチ
        await MainActor.run {
            dispatch(.executeEffect(effect.id))
        }
    }
}

// MARK: - 便利メソッド

extension BattleStore {
    
    /// 戦闘を開始する
    /// - Parameters:
    ///   - players: プレイヤーキャラクター配列
    ///   - enemies: 敵キャラクター配列
    public func startBattle(players: [Combatant], enemies: [Combatant]) {
        dispatch(.startBattle(players: players, enemies: enemies))
    }
    
    /// 戦闘を終了する
    /// - Parameter result: 戦闘結果
    public func endBattle(with result: BattleResult) {
        dispatch(.endBattle(result: result))
    }
    
    /// 攻撃を実行する
    /// - Parameters:
    ///   - attacker: 攻撃者のID
    ///   - target: 対象のID
    ///   - damage: ダメージ量
    public func performAttack(attacker: CombatantID, target: CombatantID, damage: Int) {
        dispatch(.attack(attacker: attacker, target: target, damage: damage))
    }
    
    /// HPを変更する
    /// - Parameters:
    ///   - target: 対象のID
    ///   - amount: 変更量（正の値で回復、負の値でダメージ）
    public func changeHP(target: CombatantID, amount: Int) {
        dispatch(.changeHP(target: target, amount: amount))
    }
    
    /// 現在のアクターを設定する
    /// - Parameter combatantID: アクターのID
    public func setCurrentActor(_ combatantID: CombatantID?) {
        dispatch(.setCurrentActor(combatantID))
    }
    
    /// ターンを進める
    public func advanceTurn() {
        dispatch(.advanceTurn)
    }
    
    /// フェーズを変更する
    /// - Parameter phase: 新しいフェーズ
    public func advanceToPhase(_ phase: BattlePhase) {
        dispatch(.advancePhase(phase))
    }
}

// MARK: - 状態クエリメソッド

extension BattleStore {
    
    /// 戦闘が終了しているかどうか
    public var isBattleEnded: Bool {
        return state.isBattleEnded
    }
    
    /// 生存しているプレイヤーキャラクター
    public var alivePlayers: [Combatant] {
        return state.alivePlayers
    }
    
    /// 生存している敵キャラクター
    public var aliveEnemies: [Combatant] {
        return state.aliveEnemies
    }
    
    /// 現在のフェーズ
    public var currentPhase: BattlePhase {
        return state.phase
    }
    
    /// 現在のターン数
    public var currentTurn: Int {
        return state.turnCount
    }
    
    /// 現在のアクター
    public var currentActor: CombatantID? {
        return state.currentActor
    }
    
    /// 特定のキャラクターを取得する
    /// - Parameter id: キャラクターのID
    /// - Returns: 該当するキャラクター（存在しない場合はnil）
    public func getCombatant(_ id: CombatantID) -> Combatant? {
        return state.combatants[id]
    }
    
    /// プレイヤーキャラクターかどうかを判定する
    /// - Parameter id: キャラクターのID
    /// - Returns: プレイヤーキャラクターの場合true
    public func isPlayerCombatant(_ id: CombatantID) -> Bool {
        return state.playerCombatants.contains(id)
    }
    
    /// 敵キャラクターかどうかを判定する
    /// - Parameter id: キャラクターのID
    /// - Returns: 敵キャラクターの場合true
    public func isEnemyCombatant(_ id: CombatantID) -> Bool {
        return state.enemyCombatants.contains(id)
    }
}

// MARK: - デバッグ機能

extension BattleStore {
    
    /// 現在の状態をログ出力する
    public func logCurrentState() {
        print("=== Battle State ===")
        print("Phase: \(state.phase)")
        print("Turn: \(state.turnCount)")
        print("Current Actor: \(state.currentActor?.value ?? "none")")
        print("Players: \(state.alivePlayers.count)/\(state.playerCombatants.count) alive")
        print("Enemies: \(state.aliveEnemies.count)/\(state.enemyCombatants.count) alive")
        print("Pending Effects: \(state.pendingEffects.count)")
        print("==================")
    }
    
    /// アクション履歴をログ出力する
    public func logActionHistory() {
        print("=== Action History ===")
        for (index, action) in actionHistory.enumerated() {
            print("\(index + 1). \(action)")
        }
        print("=====================")
    }
}
