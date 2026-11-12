/// Activity kinds for which an optional travelled distance is meaningful.
const calendarDistanceActivityKinds = {'walk', 'run', 'cycle', 'swim', 'hike'};

bool calendarActivityHasDistance(String? kind) =>
    calendarDistanceActivityKinds.contains(kind);
