/// Something a renderer or sound layer may want to react to. Events are
/// produced by commands and ticks, drained by the UI, and never saved.
public enum GameEvent: Equatable, Sendable {
    public enum Carrier: Equatable, Sendable { case belt, hand, truck }

    case buildingPlaced(EntityID, BuildingTypeID)
    case buildingRemoved(EntityID, BuildingTypeID)
    case beltLaid([GridPoint])
    case beltRemoved([GridPoint])
    case roadLaid([GridPoint])
    case roadRemoved([GridPoint])
    case truckRouteSet(EntityID)
    case truckRouteRemoved(EntityID)
    case pipeLaid([GridPoint])
    case pipeRemoved([GridPoint])
    /// A home got running water (true) or lost it (false).
    case waterChanged(EntityID, Bool)
    case itemProduced(EntityID, ItemID, count: Int)
    case itemDelivered(EntityID, ItemID, via: Carrier)
    case statusChanged(EntityID, MachineStatus)
    /// A foundation received everything it needs.
    case constructionCompleted(EntityID)
    case homeStarted(EntityID, by: EntityID)
    case homeCompleted(EntityID)
    case sourceDepleted(GridPoint, SourceID)
    /// A tutorial step began.
    case tutorialStep(String)
    case tutorialFinished(LevelID)
    case goalReached(LevelID)
    /// A chapter began (0-based); its land, unlocks and first step are in place.
    case chapterStarted(Int)
    /// The chapter's goal is met; the next one begins when the player continues.
    case chapterComplete(Int)
    /// A milestone after the tutorial was reached.
    case milestoneReached(String)
}
