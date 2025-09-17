/// 戦闘中に発生する全てのアクションを表現する列挙型
/// State-Storeパターンにおいて状態変更のトリガーとなる
public enum BattleAction: Sendable {
    
    // MARK: - 戦闘フロー制御
    /// 戦闘を開始する
    case startBattle(players: [Combatant], enemies: [Combatant])
    
    /// 戦闘を終了する
    case endBattle(result: BattleResult)
    
    /// 次のフェーズに移行する
    case advancePhase(BattlePhase)
    
    /// ターンを進める
    case advanceTurn
    
    // MARK: - キャラクター行動
    /// 攻撃アクション
    case attack(attacker: CombatantID, target: CombatantID, damage: Int)
    
    /// スキル使用アクション
    case useSkill(user: CombatantID, skillID: String, targets: [CombatantID])
    
    /// アイテム使用アクション
    case useItem(user: CombatantID, itemID: String, target: CombatantID?)
    
    /// 防御アクション
    case defend(defender: CombatantID)
    
    /// 逃走アクション
    case escape(escaper: CombatantID)
    
    // MARK: - ステータス変更
    /// HPを変更する
    case changeHP(target: CombatantID, amount: Int)
    
    /// MPを変更する
    case changeMP(target: CombatantID, amount: Int)
    
    /// ステータス異常を付与する
    case applyStatusEffect(target: CombatantID, effect: String, duration: Int)
    
    /// ステータス異常を解除する
    case removeStatusEffect(target: CombatantID, effect: String)
    
    // MARK: - ターン制御
    /// 現在のアクターを設定する
    case setCurrentActor(CombatantID?)
    
    /// アクション選択を開始する
    case beginActionSelection(for: CombatantID)
    
    /// アクション選択を完了する
    case completeActionSelection(for: CombatantID, action: SelectedAction)
    
    // MARK: - エフェクト制御
    /// エフェクトを追加する
    case addEffects([String])  // エフェクトIDの配列
    
    /// エフェクトを実行する
    case executeEffect(String)  // エフェクトID
    
    /// 全てのエフェクトをクリアする
    case clearEffects
    
    // MARK: - AI制御
    /// AI行動を決定する
    case aiDecideAction(for: CombatantID)
    
    /// AI行動を実行する
    case aiExecuteAction(for: CombatantID, action: SelectedAction)
}

/// 戦闘結果
public enum BattleResult: Sendable, Equatable {
    case victory    // プレイヤー勝利
    case defeat     // プレイヤー敗北
    case escape     // 逃走成功
    case draw       // 引き分け
}

/// 選択されたアクション
public enum SelectedAction: Sendable, Equatable {
    case attack(target: CombatantID)
    case skill(id: String, targets: [CombatantID])
    case item(id: String, target: CombatantID?)
    case defend
    case escape
}

/// アクションの優先度
public enum ActionPriority: Int, CaseIterable, Sendable {
    case lowest = 0
    case low = 1
    case normal = 2
    case high = 3
    case highest = 4
    
    /// 逃走アクションの優先度
    public static let escape: ActionPriority = .highest
    
    /// アイテム使用の優先度
    public static let item: ActionPriority = .high
    
    /// スキル使用の優先度（デフォルト）
    public static let skill: ActionPriority = .normal
    
    /// 通常攻撃の優先度
    public static let attack: ActionPriority = .normal
    
    /// 防御の優先度
    public static let defend: ActionPriority = .low
}

/// アクションに関連するメタデータ
public struct ActionMetadata: Sendable, Equatable {
    public let priority: ActionPriority
    public let speed: Int
    public let isInstant: Bool  // 即座に実行されるアクション
    
    public init(
        priority: ActionPriority = .normal,
        speed: Int = 0,
        isInstant: Bool = false
    ) {
        self.priority = priority
        self.speed = speed
        self.isInstant = isInstant
    }
}

extension BattleAction: Equatable {
    public static func == (lhs: BattleAction, rhs: BattleAction) -> Bool {
        switch (lhs, rhs) {
        case (.startBattle(let lp, let le), .startBattle(let rp, let re)):
            return lp == rp && le == re
        case (.endBattle(let lr), .endBattle(let rr)):
            return lr == rr
        case (.advancePhase(let lp), .advancePhase(let rp)):
            return lp == rp
        case (.advanceTurn, .advanceTurn):
            return true
        case (.attack(let la, let lt, let ld), .attack(let ra, let rt, let rd)):
            return la == ra && lt == rt && ld == rd
        case (.changeHP(let lt, let la), .changeHP(let rt, let ra)):
            return lt == rt && la == ra
        case (.addEffects(let le), .addEffects(let re)):
            return le == re
        case (.executeEffect(let le), .executeEffect(let re)):
            return le == re
        case (.clearEffects, .clearEffects):
            return true
        default:
            return false
        }
    }
    
    /// アクションのメタデータを取得する
    public var metadata: ActionMetadata {
        switch self {
        case .escape:
            return ActionMetadata(priority: .escape, isInstant: true)
        case .useItem:
            return ActionMetadata(priority: .item)
        case .defend:
            return ActionMetadata(priority: .defend)
        case .attack:
            return ActionMetadata(priority: .attack)
        case .useSkill:
            return ActionMetadata(priority: .skill)
        default:
            return ActionMetadata()
        }
    }
    
    /// アクションが戦闘フロー制御に関するものかどうか
    public var isFlowControl: Bool {
        switch self {
        case .startBattle, .endBattle, .advancePhase, .advanceTurn,
             .setCurrentActor, .beginActionSelection, .completeActionSelection:
            return true
        default:
            return false
        }
    }
    
    /// アクションがキャラクター行動に関するものかどうか
    public var isCharacterAction: Bool {
        switch self {
        case .attack, .useSkill, .useItem, .defend, .escape:
            return true
        default:
            return false
        }
    }
}
