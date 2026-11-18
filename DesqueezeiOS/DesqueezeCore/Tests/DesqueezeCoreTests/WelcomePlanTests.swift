import Testing
import DesqueezeCore

@Suite("Welcome plan")
struct WelcomePlanTests {
    @Test("a first launch shows what is new and the tour")
    func firstLaunch() {
        #expect(WelcomePlan.forLaunch(version: "1.0", lastSeenVersion: nil, tourSeen: false) == .everything)
    }

    @Test("opening the same version again shows nothing")
    func sameVersion() {
        #expect(WelcomePlan.forLaunch(version: "1.0", lastSeenVersion: "1.0", tourSeen: true).isEmpty)
    }

    @Test("an update shows what is new, and skips a tour already seen")
    func update() {
        let plan = WelcomePlan.forLaunch(version: "1.1", lastSeenVersion: "1.0", tourSeen: true)
        #expect(plan == WelcomePlan(showsWhatsNew: true, showsTour: false))
    }

    @Test("an update still offers the tour to someone who never had it")
    func updateWithoutTour() {
        let plan = WelcomePlan.forLaunch(version: "1.1", lastSeenVersion: "1.0", tourSeen: false)
        #expect(plan == .everything)
    }
}
