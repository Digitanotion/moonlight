/// The backend's live-feed country filter matches `users.country` exactly,
/// which is stored as an ISO2 code (e.g. "ZA", not "SOUTH AFRICA") — the
/// same column the video-call directory's country filter already matches
/// against successfully. With this true, the Live Now country picker sent
/// the full country name and silently matched nothing, ever, no matter
/// how many live streams existed from that country.
const bool kUseCountryNameFilter = false;
