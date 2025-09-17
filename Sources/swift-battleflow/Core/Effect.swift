/// 戦闘システムで発生する副作用を表現するプロトコル
/// アニメーション、サウンド、UI更新などの副作用を純粋なロジックから分離する
public protocol Effect: Sendable, Equatable {
    /// エフェクトの一意識別子
    var id: String { get }
    
    /// エフェクトの実行優先度（高い値ほど先に実行される）
    var priority: Int { get }
}

/// エフェクトの基本実装
public struct BaseEffect: Effect {
    public let id: String
    public let priority: Int
    
    public init(id: String, priority: Int = 0) {
        self.id = id
        self.priority = priority
    }
}

/// エフェクトなし（NoOpパターン）
public struct NoEffect: Effect {
    public let id: String = "no_effect"
    public let priority: Int = 0
    
    public init() {}
}
