//
//  TableViewExample.swift
//  TestTableView
//
//  Created by David McNerney on 2/18/16.
//  Copyright © 2016 SeatGeek. All rights reserved.
//

import UIKit


let DoExtraBrutalStressTest = false
let CountAvailableItemsExtraBrutalStressTest = 1000


let ReuseIdentifier = "ReuseIdentifier"

class TableViewExample: UIViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: Properties

    // Subviews
    let tableView: UITableView

    // Table view backing data
    let animator : SGListAnimator

    // Misc state
    var displayIteration: Int = -1
    var stressTestTimer: NSTimer?

    // MARK: Initialization

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        // Table view
        tableView = UITableView()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: ReuseIdentifier)

        // Set up animator
        animator = SGListAnimator()
        animator.doSectionMoves = true
        animator.doIntraSectionMoves = true
        animator.doInterSectionMoves = true
        animator.tableView = tableView

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        tableView.dataSource = self
        tableView.delegate = self
    }

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoder not supported")
    }

    // MARK: View life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let stressBarButtonItem = UIBarButtonItem(title: "Stress Test", style: .Plain, target: self, action: "handleStressTestButton")
        navigationItem.leftBarButtonItem = stressBarButtonItem

        let nextBarButtonItem = UIBarButtonItem(title: "Next", style: .Plain, target: self, action: "handleNextButton")
        navigationItem.rightBarButtonItem = nextBarButtonItem

        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.autoresizingMask = [ .FlexibleWidth, .FlexibleHeight ]

        navigationController?.tabBarItem = UITabBarItem(title: "Table View", image: nil, selectedImage: nil)

        // show the first iteration
        self.handleNextButton()
    }

    // MARK: Display

    func getNextStressTestSections() -> [SGListSection] {
        var availableSectionTitles = [ "A", "B", "C", "D", "E" ]
        var availableItemTitles = [
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
        ]
        if (DoExtraBrutalStressTest) {
            availableSectionTitles +=  [ "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P","Q", "R", "S", "T", "U", "V", "W", "X", "Y","Z" ]

            for i in 1...CountAvailableItemsExtraBrutalStressTest {
                availableItemTitles.append(String(i))
            }
        }

        let countSections = Int(arc4random_uniform(UInt32(availableSectionTitles.count)))
        var sections = [SGListSection]()
        for _ in 0..<countSections {
            if availableItemTitles.isEmpty {
                break
            }

            let section = SGListSection()
            let sectionArrayIndex = Int(arc4random_uniform(UInt32(availableSectionTitles.count)))
            section.title = availableSectionTitles[sectionArrayIndex]
            availableSectionTitles.removeAtIndex(sectionArrayIndex)

            let countItems = Int(arc4random_uniform(UInt32(availableItemTitles.count)))
            var items = [String]()
            for _ in 0..<countItems {
                let itemArrayIndex = Int(arc4random_uniform(UInt32(availableItemTitles.count)))
                let item = availableItemTitles[itemArrayIndex]
                availableItemTitles.removeAtIndex(itemArrayIndex)
                items.append(item)
            }
            section.items = items

            sections.append(section)
        }

        return sections
    }

    func getNextDisplaySections() -> [SGListSection] {
        displayIteration++
        if displayIteration < iterations.count {
            return self.sectionsForString(iterations[displayIteration])
        } else {
            return []
        }
    }

    let iterations = [
        // See SGListAnimatorTests.m for documentation of this string format
        "",
        "A.a",
        "A.abcdefghij",
        "A.abcdefghij,B.k",
        "A.abcdefghij,B.klmnopq",
        "A.abcde,B.klmnopq",
        "A.abc,B.def,C.ghi,D.jkl",
        "A.abcz,D.jkl,B.def,E.mno",
        "A.abc,B.def",
        "B.de,A.abcf",
        "A.abc,B.defg",
        "A.acde,B.bklmnopq",
        "A.a,B.bdefghijck",            // too many changes by current limit rule
        "B.bdefghijck,A.a",            // section move
        "B.edbfghijck,A.a",            // intra-section move
        "A.ae,B.ghidbfjck",            // section move, intra-section move, and inter-section move all at once
        "A.a",
        "B.a",
        "A.a,B.b",
        "A.abcde,B.f",
        "A.a,B.fedcb",
        "A.afde,C.ghi,D.j",
        "A.af,C.g",
        "A.af,D.g",
        "A.afg",
        "",
        "A.abc",
        "A.ijkadbecfgh",
        "A.a,B.bcdef",
        "B.abcdef",
        "B.acdef",
        "B.acf",

        // Used to crash us
        "C.wbimgkqaxvslonp,D.terczhfdujy",
        "A.dhvlrxbjg,B.o,C.kszwquc",
    ]

    func sectionsForString(inString: String) -> [SGListSection] {
        var sections = [SGListSection]()
        for sectionString in splitString(inString, byString: ",") {
            let titleAndItems = self.splitString(sectionString, byString: ".")
            let section = SGListSection()
            section.title = titleAndItems[0]
            section.items = self.divideStringIntoOneCharacterStrings(titleAndItems[1])
            sections.append(section)
        }
        return sections
    }

    func splitString(inString: String, byString: String) -> [String] {
        if inString.isEmpty {
            return []
        }
        return inString.componentsSeparatedByString(byString)
    }

    func divideStringIntoOneCharacterStrings(inString: String) -> [String] {
        var oneCharacterStrings = [String]()
        for character in inString.characters {
            oneCharacterStrings.append(String(character))
        }
        return oneCharacterStrings
    }

    // MARK: Actions

    func handleStressTestButton() {
        if stressTestTimer != nil {
            stressTestTimer?.invalidate()
            stressTestTimer = nil
        } else {
            stressTestTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: "doNextStressTestIteration", userInfo: nil, repeats: true)
        }
    }

    func handleNextButton() {
        self.animator.transitionTableViewToSections(self.getNextDisplaySections())
    }

    // MARK: Stress test

    func doNextStressTestIteration() {
        self.animator.transitionTableViewToSections(self.getNextStressTestSections())
    }

    // MARK: UITableView

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return animator.currentSections != nil ? animator.currentSections!.count : 0
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return animator.currentSections?[section].title
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return animator.currentSections![section].items!.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ReuseIdentifier, forIndexPath: indexPath)
        cell.textLabel!.text = self.animator.currentSections![indexPath.section].items![indexPath.row] as? String
        return cell
    }
}
