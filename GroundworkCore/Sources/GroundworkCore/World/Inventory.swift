/// Items held by a building or a crate.
///
/// Stored as a sorted array rather than a dictionary: Swift dictionaries
/// iterate and encode in a different order on every run, which would break
/// deterministic saves.
public struct Inventory: Codable, Equatable, Sendable {
    public private(set) var stacks: [ItemStack] = []

    public init(_ stacks: [ItemStack] = []) {
        for stack in stacks { add(stack.item, stack.count) }
    }

    public var total: Int { stacks.reduce(0) { $0 + $1.count } }
    public var isEmpty: Bool { stacks.isEmpty }

    public func count(of item: ItemID) -> Int {
        index(of: item).map { stacks[$0].count } ?? 0
    }

    public func contains(_ needed: [ItemStack]) -> Bool {
        needed.allSatisfy { count(of: $0.item) >= $0.count }
    }

    public mutating func add(_ item: ItemID, _ count: Int) {
        guard count > 0 else { return }
        if let index = index(of: item) {
            stacks[index].count += count
        } else {
            let position = stacks.firstIndex { $0.item > item } ?? stacks.endIndex
            stacks.insert(ItemStack(item: item, count: count), at: position)
        }
    }

    /// Removes up to `count` and returns how many were removed.
    @discardableResult
    public mutating func remove(_ item: ItemID, _ count: Int) -> Int {
        guard count > 0, let index = index(of: item) else { return 0 }
        let removed = min(count, stacks[index].count)
        stacks[index].count -= removed
        if stacks[index].count == 0 { stacks.remove(at: index) }
        return removed
    }

    private func index(of item: ItemID) -> Int? {
        stacks.firstIndex { $0.item == item }
    }
}
