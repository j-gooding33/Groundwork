/// Finds where a dragged belt goes: the cheapest path over free land, with a
/// small cost for each turn so belts prefer straight runs. Ties always break
/// the same way, so the same drag always gives the same belt.
struct BeltPlan: Equatable {
    var points: [GridPoint]
    var directions: [Direction]
    var pullsFrom: EntityID?
}

enum BeltRouting {
    private static let stepCost = 10
    private static let turnCost = 4

    static func plan(from: GridPoint, to: GridPoint, world: World, content: ContentDatabase) -> Result<BeltPlan, CommandError> {
        // Where the belt may start.
        var starts: [GridPoint]
        var pullsFrom: EntityID?
        var awayFromSource: [GridPoint: Direction] = [:]
        if let source = world.building(at: from), let def = content.building(source.type) {
            pullsFrom = source.id
            starts = []
            for point in source.footprint(def) {
                for direction in Direction.allCases {
                    let candidate = point.moved(direction)
                    if world.isFree(candidate), awayFromSource[candidate] == nil {
                        starts.append(candidate)
                        awayFromSource[candidate] = direction
                    }
                }
            }
            if starts.isEmpty { return .failure(.noRoom("There is no free tile beside the \(def.name)")) }
        } else if world.isFree(from) {
            starts = [from]
        } else {
            return .failure(.blocked("A belt cannot start there"))
        }

        // Where it may end, and which way the last tile must face.
        var goals: [GridPoint: Direction?] = [:]
        if let target = world.building(at: to), let def = content.building(target.type) {
            if target.id == pullsFrom { return .failure(.blocked("A belt needs to go somewhere else")) }
            for point in target.footprint(def) {
                for direction in Direction.allCases {
                    let candidate = point.moved(direction)
                    if world.isFree(candidate) || starts.contains(candidate), goals[candidate] == nil {
                        goals[candidate] = .some(direction.opposite)
                    }
                }
            }
        } else if let belt = world.belt(at: to) {
            for direction in Direction.allCases {
                let candidate = to.moved(direction)
                let facing = direction.opposite
                if world.isFree(candidate), facing != belt.direction.opposite, goals[candidate] == nil {
                    goals[candidate] = .some(facing)
                }
            }
        } else if world.isFree(to) {
            goals[to] = .some(nil)
        } else {
            return .failure(.blocked("A belt cannot end there"))
        }
        if goals.isEmpty { return .failure(.noRoom("There is no free tile to end the belt on")) }

        guard let path = shortestPath(starts: starts.sorted(), goals: goals, world: world) else {
            return .failure(.noRoute("No clear path for a belt"))
        }

        var directions: [Direction] = []
        for k in path.indices {
            if k + 1 < path.count {
                directions.append(direction(from: path[k], to: path[k + 1]))
            } else if let fixed = goals[path[k]] ?? nil {
                directions.append(fixed)
            } else if k > 0 {
                directions.append(direction(from: path[k - 1], to: path[k]))
            } else {
                directions.append(awayFromSource[path[k]] ?? .east)
            }
        }
        return .success(BeltPlan(points: path, directions: directions, pullsFrom: pullsFrom))
    }

    private static func direction(from a: GridPoint, to b: GridPoint) -> Direction {
        Direction.allCases.first { a.moved($0) == b } ?? .east
    }

    /// Dijkstra over (tile, arrival direction).
    private static func shortestPath(starts: [GridPoint], goals: [GridPoint: Direction?], world: World) -> [GridPoint]? {
        let width = world.map.width
        let directions = Direction.allCases
        let none = directions.count
        let stateCount = width * world.map.height * (none + 1)
        func state(_ p: GridPoint, _ d: Int) -> Int { (p.y * width + p.x) * (none + 1) + d }

        var cost = Array(repeating: Int.max, count: stateCount)
        var previous = Array(repeating: -1, count: stateCount)
        var heap = MinHeap()
        for start in starts {
            let s = state(start, none)
            cost[s] = 0
            heap.push(Entry(cost: 0, y: start.y, x: start.x, d: none))
        }

        while let entry = heap.pop() {
            let point = GridPoint(entry.x, entry.y)
            let s = state(point, entry.d)
            if entry.cost > cost[s] { continue }
            if goals[point] != nil {
                var path: [GridPoint] = []
                var current = s
                while current >= 0 {
                    let cell = current / (none + 1)
                    path.append(GridPoint(cell % width, cell / width))
                    current = previous[current]
                }
                return path.reversed()
            }
            for (d, direction) in directions.enumerated() {
                let next = point.moved(direction)
                guard world.isFree(next) else { continue }
                let turn = entry.d != none && entry.d != d ? turnCost : 0
                let newCost = entry.cost + stepCost + turn
                let ns = state(next, d)
                if newCost < cost[ns] {
                    cost[ns] = newCost
                    previous[ns] = s
                    heap.push(Entry(cost: newCost, y: next.y, x: next.x, d: d))
                }
            }
        }
        return nil
    }

    private struct Entry {
        var cost: Int, y: Int, x: Int, d: Int
        static func < (a: Entry, b: Entry) -> Bool { (a.cost, a.y, a.x, a.d) < (b.cost, b.y, b.x, b.d) }
    }

    private struct MinHeap {
        private var items: [Entry] = []

        mutating func push(_ entry: Entry) {
            items.append(entry)
            var child = items.count - 1
            while child > 0 {
                let parent = (child - 1) / 2
                guard items[child] < items[parent] else { break }
                items.swapAt(child, parent)
                child = parent
            }
        }

        mutating func pop() -> Entry? {
            guard !items.isEmpty else { return nil }
            items.swapAt(0, items.count - 1)
            let top = items.removeLast()
            var parent = 0
            while true {
                let left = parent * 2 + 1
                let right = left + 1
                var smallest = parent
                if left < items.count, items[left] < items[smallest] { smallest = left }
                if right < items.count, items[right] < items[smallest] { smallest = right }
                if smallest == parent { break }
                items.swapAt(parent, smallest)
                parent = smallest
            }
            return top
        }
    }
}
