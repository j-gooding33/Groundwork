/// Something a renderer or sound layer may want to react to. Events are
/// produced by commands and ticks, drained by the UI, and never saved.
public enum GameEvent: Equatable, Sendable {
    public enum Carrier: Equatable, Sendable { case belt, hand }

    case buildingPlaced(EntityID, BuildingTypeID)
    case buildingRemoved(EntityID, BuildingTypeID)
    case beltLaid([GridPoint])
    case beltRemoved([GridPoint])
    case itemProduced(EntityID, ItemID, count: Int)
    case itemDelivered(EntityID, ItemID, via: Carrier)
    case statusChanged(EntityID, MachineStatus)
    /// A foundation received everything it needs.
    case constructionCompleted(EntityID)
    case homeStarted(EntityID, by: EntityID)
    case homeCompleted(EntityID)
    case sourceDepleted(GridPoint, SourceID)
}
