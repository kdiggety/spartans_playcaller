import XCTest
@testable import SpartansPlaycaller

@MainActor
final class EditPlayViewModelTests: XCTestCase {

    var tempURL: URL!
    var store: PlayLibraryStore!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-test-\(UUID()).json")
        store = PlayLibraryStore(fileURL: tempURL)
        let interpreter = RouteInterpreter()
        guard case .success(let pc) = interpreter.interpret(digits: "6794", formation: .twins) else {
            XCTFail("Seed play failed"); return
        }
        store.save(pc, motion: nil, yWheelEnabled: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testInit_populatesFieldsFromSavedPlay() {
        let play = store.plays[0]
        let vm = EditPlayViewModel(play: play)
        XCTAssertEqual(vm.selectedFormation, .twins)
        XCTAssertEqual(vm.routeDigitInput, "6794")
        XCTAssertNil(vm.selectedMotion)
        XCTAssertFalse(vm.yWheelEnabled)
        XCTAssertNil(vm.validationError)
        XCTAssertFalse(vm.isDirty)
    }

    func testIsDirty_trueAfterDigitChange() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = "9999"
        XCTAssertTrue(vm.isDirty)
    }

    func testIsDirty_falseAfterRevertingChange() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = "9999"
        vm.routeDigitInput = "6794"
        XCTAssertFalse(vm.isDirty, "isDirty must be false when all fields match original")
    }

    func testValidateInput_setsErrorOnEmpty() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = ""
        vm.validateInput()
        XCTAssertNotNil(vm.validationError)
    }

    func testValidateInput_clearsErrorOnValidInput() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = ""
        vm.validateInput()
        vm.routeDigitInput = "6794"
        vm.validateInput()
        XCTAssertNil(vm.validationError)
    }

    func testSave_successSetsDidSave() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = "6794"
        vm.save(to: store)
        XCTAssertTrue(vm.didSave)
        XCTAssertNil(vm.persistError)
    }

    func testSave_invalidDigits_setsValidationError() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.routeDigitInput = ""
        vm.save(to: store)
        XCTAssertNotNil(vm.validationError)
        XCTAssertFalse(vm.didSave)
    }

    func testSave_updatesStorePlay() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.selectedMotion = .stop
        vm.routeDigitInput = "6794"
        vm.save(to: store)
        XCTAssertEqual(store.plays[0].motionLabel, ReceiverMotion.stop.rawValue)
    }

    func testValidateInput_usesCurrentFormation() {
        let vm = EditPlayViewModel(play: store.plays[0])
        vm.selectedFormation = .tripsLeft
        vm.routeDigitInput = ""
        vm.validateInput()
        XCTAssertNotNil(vm.validationError, "Validation must run against the selected formation")
    }

    func testSave_playNotFound_setsPersistError() {
        // Use a play that was never saved to the store
        let phantom = SavedPlay(
            id: UUID(), savedAt: Date(),
            formationName: "Twins", routeDigits: "6794",
            conceptName: nil, motionLabel: nil, yWheelEnabled: false
        )
        let vm = EditPlayViewModel(play: phantom)
        vm.routeDigitInput = "6794"
        vm.save(to: store)
        XCTAssertNotNil(vm.persistError, "persistError must be set when play no longer exists")
        XCTAssertFalse(vm.didSave)
    }
}
