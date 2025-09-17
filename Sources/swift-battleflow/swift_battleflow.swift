/// Swift BattleFlow - JRPGスタイルのターン制戦闘システムライブラリ
/// 
/// Pure SwiftでState-Storeパターンを採用し、副作用をEffectとして分離した
/// モダンで保守性の高い戦闘システムを提供します。

// MARK: - Core Exports

@_exported import Foundation
@_exported import Observation

// Core Components are directly available through their module

// MARK: - Convenience Factory

/// BattleFlowライブラリのメインエントリーポイント
public struct BattleFlow {
    
    /// 新しい戦闘ストアを作成する
    /// - Parameter initialState: 初期状態（省略時は空の状態）
    /// - Returns: 設定済みのBattleStore
    @MainActor
    public static func createStore(initialState: BattleState = BattleState()) -> BattleStore {
        return BattleStore(initialState: initialState)
    }
    
    /// デモ用のキャラクターを作成する
    /// - Parameters:
    ///   - name: キャラクター名
    ///   - hp: 現在のHP
    ///   - maxHP: 最大HP（省略時は現在のHPと同じ）
    ///   - mp: 現在のMP
    ///   - maxMP: 最大MP（省略時は現在のMPと同じ）
    ///   - attack: 攻撃力
    ///   - defense: 防御力
    ///   - speed: 速度
    ///   - isPlayer: プレイヤーキャラクターかどうか
    /// - Returns: 設定済みのCombatant
    public static func createCharacter(
        name: String,
        hp: Int = 100,
        maxHP: Int? = nil,
        mp: Int = 50,
        maxMP: Int? = nil,
        attack: Int = 20,
        defense: Int = 15,
        speed: Int = 10,
        isPlayer: Bool = true
    ) -> Combatant {
        let id = CombatantID(name.lowercased().replacingOccurrences(of: " ", with: "_"))
        let stats = Stats(
            hp: hp, 
            maxHP: maxHP ?? hp,
            mp: mp, 
            maxMP: maxMP ?? mp,
            attack: attack,
            defense: defense,
            speed: speed
        )
        
        return Combatant(
            id: id,
            name: name,
            stats: stats,
            isPlayerControlled: isPlayer
        )
    }
}
