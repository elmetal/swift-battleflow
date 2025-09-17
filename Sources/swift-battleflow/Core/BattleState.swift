import Foundation

/// 戦闘の現在フェーズを表現
public enum BattlePhase: Sendable, Equatable {
    case preparation    // 戦闘準備
    case turnSelection  // ターン選択
    case actionExecution // アクション実行
    case effectResolution // エフェクト解決
    case victory       // 勝利
    case defeat        // 敗北
    case escape        // 逃走
}

/// 戦闘参加者の基本情報
public struct CombatantID: Hashable, Sendable {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
}

/// 基本ステータス
public struct Stats: Sendable, Equatable {
    public let hp: Int
    public let maxHP: Int
    public let mp: Int
    public let maxMP: Int
    public let attack: Int
    public let defense: Int
    public let speed: Int
    
    public init(
        hp: Int,
        maxHP: Int,
        mp: Int,
        maxMP: Int,
        attack: Int,
        defense: Int,
        speed: Int
    ) {
        self.hp = hp
        self.maxHP = maxHP
        self.mp = mp
        self.maxMP = maxMP
        self.attack = attack
        self.defense = defense
        self.speed = speed
    }
    
    /// HPが0以下かどうか
    public var isDefeated: Bool {
        return hp <= 0
    }
    
    /// HPを変更した新しいStatsを返す
    public func withHP(_ newHP: Int) -> Stats {
        Stats(
            hp: max(0, min(newHP, maxHP)),
            maxHP: maxHP,
            mp: mp,
            maxMP: maxMP,
            attack: attack,
            defense: defense,
            speed: speed
        )
    }
    
    /// MPを変更した新しいStatsを返す
    public func withMP(_ newMP: Int) -> Stats {
        Stats(
            hp: hp,
            maxHP: maxHP,
            mp: max(0, min(newMP, maxMP)),
            maxMP: maxMP,
            attack: attack,
            defense: defense,
            speed: speed
        )
    }
}

/// 戦闘参加者
public struct Combatant: Sendable, Equatable {
    public let id: CombatantID
    public let name: String
    public let stats: Stats
    public let isPlayerControlled: Bool
    
    public init(
        id: CombatantID,
        name: String,
        stats: Stats,
        isPlayerControlled: Bool
    ) {
        self.id = id
        self.name = name
        self.stats = stats
        self.isPlayerControlled = isPlayerControlled
    }
    
    /// 新しいStatsで更新されたCombatantを返す
    public func withStats(_ newStats: Stats) -> Combatant {
        Combatant(
            id: id,
            name: name,
            stats: newStats,
            isPlayerControlled: isPlayerControlled
        )
    }
}

/// 戦闘の現在状態を表すイミュータブルな構造体
public struct BattleState: Sendable, Equatable {
    /// 現在の戦闘フェーズ
    public let phase: BattlePhase
    
    /// 戦闘参加者一覧
    public let combatants: [CombatantID: Combatant]
    
    /// プレイヤーキャラクターのID一覧
    public let playerCombatants: Set<CombatantID>
    
    /// 敵キャラクターのID一覧
    public let enemyCombatants: Set<CombatantID>
    
    /// 現在のターン数
    public let turnCount: Int
    
    /// 現在アクション中のキャラクターID
    public let currentActor: CombatantID?
    
    /// 保留中のエフェクト一覧
    public let pendingEffects: [any Effect]
    
    public init(
        phase: BattlePhase = .preparation,
        combatants: [CombatantID: Combatant] = [:],
        playerCombatants: Set<CombatantID> = [],
        enemyCombatants: Set<CombatantID> = [],
        turnCount: Int = 0,
        currentActor: CombatantID? = nil,
        pendingEffects: [any Effect] = []
    ) {
        self.phase = phase
        self.combatants = combatants
        self.playerCombatants = playerCombatants
        self.enemyCombatants = enemyCombatants
        self.turnCount = turnCount
        self.currentActor = currentActor
        self.pendingEffects = pendingEffects
    }
    
    /// 戦闘が終了しているかどうか
    public var isBattleEnded: Bool {
        switch phase {
        case .victory, .defeat, .escape:
            return true
        default:
            return false
        }
    }
    
    /// 生存しているプレイヤーキャラクター
    public var alivePlayers: [Combatant] {
        playerCombatants.compactMap { id in
            combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
        }
    }
    
    /// 生存している敵キャラクター
    public var aliveEnemies: [Combatant] {
        enemyCombatants.compactMap { id in
            combatants[id]?.stats.isDefeated == false ? combatants[id] : nil
        }
    }
    
    /// 戦闘参加者を更新した新しいBattleStateを返す
    public func withCombatant(_ combatant: Combatant) -> BattleState {
        var newCombatants = combatants
        newCombatants[combatant.id] = combatant
        
        return BattleState(
            phase: phase,
            combatants: newCombatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects
        )
    }
    
    /// フェーズを更新した新しいBattleStateを返す
    public func withPhase(_ newPhase: BattlePhase) -> BattleState {
        BattleState(
            phase: newPhase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects
        )
    }
    
    /// エフェクトを追加した新しいBattleStateを返す
    public func withEffects(_ effects: [any Effect]) -> BattleState {
        BattleState(
            phase: phase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: pendingEffects + effects
        )
    }
    
    /// エフェクトをクリアした新しいBattleStateを返す
    public func withClearedEffects() -> BattleState {
        BattleState(
            phase: phase,
            combatants: combatants,
            playerCombatants: playerCombatants,
            enemyCombatants: enemyCombatants,
            turnCount: turnCount,
            currentActor: currentActor,
            pendingEffects: []
        )
    }
}

extension BattleState {
    /// Equatableの実装（pendingEffectsはtype erasedなので個別比較）
    public static func == (lhs: BattleState, rhs: BattleState) -> Bool {
        lhs.phase == rhs.phase &&
        lhs.combatants == rhs.combatants &&
        lhs.playerCombatants == rhs.playerCombatants &&
        lhs.enemyCombatants == rhs.enemyCombatants &&
        lhs.turnCount == rhs.turnCount &&
        lhs.currentActor == rhs.currentActor &&
        lhs.pendingEffects.count == rhs.pendingEffects.count
        // Note: pendingEffectsの詳細比較は今後必要に応じて実装
    }
}
