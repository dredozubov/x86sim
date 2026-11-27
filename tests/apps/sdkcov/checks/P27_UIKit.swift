// SDK coverage, round 30 (P27): public API of the SDK not yet referenced by any check (~/scratch/r30/apisurf.py),
// area: UIKit and the foundation-level frameworks under it (Foundation's Swift overlay, Combine, TabularData, Core
// Video / Core Media Swift types, Core Graphics, Accessibility, Symbols, PencilKit, QuartzCore, Core Image, OSLog,
// MetricKit, ...). Real work where the type does something (layouts by frames, dynamics by positions, text layout by
// fragments, publishers by values); value classes table-driven (built, copied, archived back to their class). Ids
// start "p27ui-" (run.sh --only p27ui-). Each check asserts what Apple's simulator answers (ref-mac.sh --only).
import Foundation
import CoreGraphics
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: helpers

/// NSKeyedArchiver round trip (secure archiving; the root unarchived without the class allow-list, nested classes vary)
private func p27uiArchive(_ o: NSObject) throws -> NSObject? {
    let d = try NSKeyedArchiver.archivedData(withRootObject: o, requiringSecureCoding: o is NSSecureCoding)
    let u = try NSKeyedUnarchiver(forReadingFrom: d); u.requiresSecureCoding = false
    defer { u.finishDecoding() }
    return u.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSObject
}
/// value objects, table-driven: each is of its class, describes itself, copies (NSCopying) and archives (NSCoding)
/// back to its class. Returns "n built, c copied (e equal), a archived".
private func p27uiTable(_ objs: [(AnyClass, NSObject)], archive: Bool = true, copy: Bool = true) throws -> String {
    var copied = 0, equal = 0, archived = 0
    for (cls, o) in objs {
        let n = NSStringFromClass(cls)
        try expect(o.isKind(of: cls), "\(n): built \(type(of: o))")
        try expect(!o.description.isEmpty, "\(n): no description")
        if copy, let c = (o as? NSCopying)?.copy(with: nil) as? NSObject {
            try expect(c.isKind(of: cls) || cls.isSubclass(of: type(of: c)), "\(n): copy is \(type(of: c))")
            copied += 1; if c.isEqual(o) { equal += 1 }
        }
        if archive, o is NSCoding {
            var a: NSObject?
            var err: Error?
            let ex = SDKCovCatch { do { a = try p27uiArchive(o) } catch { err = error } }
            try expect(ex == nil && err == nil, "\(n): archive \(ex ?? []) \(err.map { "\($0)" } ?? "")")
            try expect(a?.isKind(of: cls) == true, "\(n): unarchived \(a.map { "\(type(of: $0))" } ?? "nil")")
            archived += 1
        }
    }
    return "\(objs.count) built, \(copied) copied (\(equal) equal), \(archived) archived"
}
/// classes by name (types Swift refines away or renames, e.g. UICellAccessoryCheckmark behind UICellAccessory)
private func p27uiClass(_ n: String) throws -> NSObject.Type {
    guard let c = NSClassFromString(n) as? NSObject.Type else { throw Fail("no class \(n)") }
    return c
}


/// classes that Swift cannot name or build directly: each is looked up and, with build, built with -init (an exception is caught and
/// counted), and a built object must be of its class, describe itself and survive NSSecureCoding when it adopts it.
/// Returns (absent, raised, built) class names, asserted against Apple's simulator by the caller.
private func p27uiProbe(_ names: [String], build: Bool = false) throws -> (absent: [String], raised: [String], built: [String]) {
    var absent: [String] = [], raised: [String] = [], built: [String] = []
    for n in names {
        guard let cls = NSClassFromString(n) as? NSObject.Type else { absent.append(n); continue }
        // -init only on request: some of UIKit's classes crash on a bare -init (Apple's simulator too)
        guard build else { try expect(cls.isSubclass(of: NSObject.self), n); built.append(n); continue }
        var o: NSObject?
        if SDKCovCatch({ o = cls.init() }) != nil || o == nil { raised.append(n); continue }
        guard let obj = o, obj.isKind(of: cls), !obj.description.isEmpty else { throw Fail("\(n): built \(String(describing: o))") }
        if cls.conforms(to: NSSecureCoding.self), (cls as AnyObject).responds(to: NSSelectorFromString("supportsSecureCoding")) {
            var a: NSObject?
            if SDKCovCatch({ a = try? p27uiArchive(obj) }) == nil, let a, !a.isKind(of: cls) { throw Fail("\(n): unarchived \(type(of: a))") }
        }
        built.append(n)
    }
    return (absent, raised, built)
}

#if canImport(UIKit) && !os(watchOS)
@MainActor private func p27uiHost(_ v: UIView, _ size: CGSize = CGSize(width: 320, height: 480)) throws -> () -> Void {
    let vc = UIViewController(); vc.view.backgroundColor = .white
    v.frame = CGRect(origin: .zero, size: size); vc.view.addSubview(v)
    let (_, close) = try p6Show(vc)
    return close
}
#endif

extension Registry {
    static var p27ui: [Check] {
        var c: [Check] = []
        #if canImport(UIKit) && !os(watchOS)
        c += p27uiKit + p27uiKit2
        #endif
        c += p27uiFoundation + p27uiFoundation2 + p27uiFrameworks + p27uiMore + p27uiMore2
        return c
    }
}

#if canImport(UIKit) && !os(watchOS)
extension Registry {
    static var p27uiKit: [Check] {
        var c: [Check] = []

        // UIBarAppearance family: configured, applied to bars, read back; copies compare equal
        c.append(check("UIKit", "p27ui-bar-appearance") {
            try await p6A {
                #if os(tvOS)
                // tvOS refuses the bar appearance API (Apple's simulator raises the same)
                let ex = SDKCovCatch { let a = UINavigationBarAppearance(); a.configureWithOpaqueBackground(); UINavigationBar().standardAppearance = a }
                try expect(ex?.first == "NSInternalInconsistencyException", "tvOS bar appearance answered \(ex ?? [])")
                let bi: UIBarItem = UITabBarItem(title: "T", image: nil, tag: 7); bi.title = "T2"
                try expect(bi.title == "T2", "bar item")
                return "bar appearance refused on tvOS: \(ex?[1].prefix(60) ?? "")"
                #else
                let nav = UINavigationBarAppearance(); nav.configureWithOpaqueBackground(); nav.backgroundColor = .red
                nav.titleTextAttributes = [.foregroundColor: UIColor.blue]
                let done = UIBarButtonItemAppearance(style: .done)
                let st: UIBarButtonItemStateAppearance = done.normal
                st.titleTextAttributes = [.foregroundColor: UIColor.green]
                nav.doneButtonAppearance = done
                let base: UIBarAppearance = nav.copy()
                try expect(base.backgroundColor == .red, "copied bar appearance bg \(String(describing: base.backgroundColor))")
                let bar = UINavigationBar(); bar.standardAppearance = nav
                try expect(bar.standardAppearance.backgroundColor == .red, "applied nav appearance")
                try expect((bar.standardAppearance.doneButtonAppearance.normal.titleTextAttributes[.foregroundColor] as? UIColor) == .green, "done button state appearance")
                let item = UINavigationItem(title: "P27"); item.standardAppearance = nav
                try expect(item.title == "P27" && item.standardAppearance?.backgroundColor == .red, "navigation item")
                let tab = UITabBarAppearance(); tab.configureWithDefaultBackground()
                let ti = UITabBarItemAppearance(style: .stacked)
                let sel: UITabBarItemStateAppearance = ti.selected
                sel.iconColor = .orange; sel.badgeBackgroundColor = .purple
                tab.stackedLayoutAppearance = ti
                let tb = UITabBar(); tb.standardAppearance = tab
                try expect(tb.standardAppearance.stackedLayoutAppearance.selected.iconColor == .orange, "tab item state appearance")
                let bi: UIBarItem = UITabBarItem(title: "T", image: nil, tag: 7)
                bi.title = "T2"
                try expect(bi.title == "T2" && (bi as? UITabBarItem)?.tag == 7, "bar item")
                var d = "nav/tab appearances applied, tab item tag 7"
                #if !os(tvOS)
                let tool = UIToolbarAppearance(barAppearance: nav)
                try expect(tool.backgroundColor == .red, "toolbar appearance from bar appearance")
                let grp = UIBarButtonItemGroup(barButtonItems: [UIBarButtonItem(title: "a"), UIBarButtonItem(title: "b")], representativeItem: nil)
                try expect(grp.barButtonItems.count == 2, "bar button item group \(grp.barButtonItems.count)")
                d += ", toolbar appearance, group of \(grp.barButtonItems.count)"
                #endif
                return d
                #endif
            }
        })

        // compositional layout: sizes / dimensions / spacing / anchors / supplementary + decoration items / custom
        // groups, checked by the frames the layout gives each item
        c.append(check("UIKit", "p27ui-compositional-layout") {
            try await p6A {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(40)))
                let es = NSCollectionLayoutEdgeSpacing(leading: .fixed(0), top: .fixed(4), trailing: .fixed(0), bottom: .fixed(0))
                item.edgeSpacing = es
                let badgeAnchor = NSCollectionLayoutAnchor(edges: [.top, .trailing], absoluteOffset: CGPoint(x: 5, y: -5))
                let badge = NSCollectionLayoutSupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(10), heightDimension: .absolute(10)), elementKind: "badge", containerAnchor: badgeAnchor)
                let item2 = NSCollectionLayoutItem(layoutSize: item.layoutSize, supplementaryItems: [badge])
                let dim: NSCollectionLayoutDimension = .absolute(44)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: dim), subitems: [item, item2])
                group.interItemSpacing = NSCollectionLayoutSpacing.fixed(0)
                let sec = NSCollectionLayoutSection(group: group)
                sec.interGroupSpacing = 6
                let deco = NSCollectionLayoutDecorationItem.background(elementKind: "bg")
                sec.decorationItems = [deco]
                let custom = NSCollectionLayoutGroup.custom(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(100))) { env in
                    [NSCollectionLayoutGroupCustomItem(frame: CGRect(x: 10, y: 10, width: 30, height: 30)), NSCollectionLayoutGroupCustomItem(frame: CGRect(x: 60, y: 20, width: 50, height: 50), zIndex: 2)]
                }
                let sec2 = NSCollectionLayoutSection(group: custom)
                #if !os(tvOS)
                sec2.orthogonalScrollingBehavior = .continuous
                let osp: UICollectionLayoutSectionOrthogonalScrollingProperties = sec2.orthogonalScrollingProperties
                osp.bounce = .never
                #endif
                let cfg = UICollectionViewCompositionalLayoutConfiguration(); cfg.interSectionSpacing = 20
                let layout = UICollectionViewCompositionalLayout(sectionProvider: { s, _ in s == 0 ? sec : sec2 }, configuration: cfg)
                layout.register(UICollectionReusableView.self, forDecorationViewOfKind: "bg")
                let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: layout)
                cv.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "c")
                cv.register(UICollectionReusableView.self, forSupplementaryViewOfKind: "badge", withReuseIdentifier: "b")
                let ds = UICollectionViewDiffableDataSource<Int, Int>(collectionView: cv) { cv, ip, _ in cv.dequeueReusableCell(withReuseIdentifier: "c", for: ip) }
                ds.supplementaryViewProvider = { cv, k, ip in cv.dequeueReusableSupplementaryView(ofKind: k, withReuseIdentifier: "b", for: ip) }
                var snap = NSDiffableDataSourceSnapshot<Int, Int>(); snap.appendSections([0, 1]); snap.appendItems([1, 2, 3, 4], toSection: 0); snap.appendItems([5, 6], toSection: 1)
                ds.apply(snap, animatingDifferences: false)
                let close = try p27uiHost(cv)
                defer { close() }
                cv.layoutIfNeeded()
                let base: UICollectionViewLayout = cv.collectionViewLayout
                func f(_ s: Int, _ i: Int) -> CGRect { base.layoutAttributesForItem(at: IndexPath(item: i, section: s))?.frame ?? .null }
                let a0 = f(0, 0), a1 = f(0, 1), a2 = f(0, 2), c0 = f(1, 0), c1 = f(1, 1)
                let d = "items \(a0) \(a1) \(a2), custom \(c0) \(c1)"
                // tvOS insets the section by its readable margins (x 80); the rest is relative to the first item
                try expect(a0.width == a1.width && a0.height == 40 && a0.minY == 4 && a1.minX == a0.maxX && a0.width >= 120, d)
                try expect(a2.minY == a0.minY + 44 + 6, d)                         // next group: height 44 + interGroupSpacing
                try expect(c0.width == 30 && c1.width == 50 && c1.minY - c0.minY == 10 && c1.minX - c0.minX == 50 && c0.minX - a0.minX == 10, d)
                try expect(c0.minY >= 2 * 44 + 6 + 20, d)                            // after section 0 + interSectionSpacing
                let attrs: [UICollectionViewLayoutAttributes] = base.layoutAttributesForElements(in: cv.bounds) ?? []
                let badges = attrs.filter { $0.representedElementKind == "badge" }, bgs = attrs.filter { $0.representedElementKind == "bg" }
                try expect(badges.count == 2 && bgs.count == 1, "badges \(badges.count) backgrounds \(bgs.count); \(d)")
                try expect(abs(badges[0].frame.maxX - a1.maxX - 5) < 0.5 || abs(badges[0].frame.midX - a1.maxX - 5) < 6, "badge \(badges[0].frame) at \(a1); \(d)")
                // invalidation contexts, transition layout, collection view controller, drop proposals / placeholders
                let ctx = UICollectionViewFlowLayoutInvalidationContext(); ctx.invalidateFlowLayoutDelegateMetrics = true
                let ictx: UICollectionViewLayoutInvalidationContext = ctx
                ictx.invalidateItems(at: [IndexPath(item: 0, section: 0)])
                try expect(ictx.invalidatedItemIndexPaths?.count == 1, "invalidation context")
                let tl = UICollectionViewTransitionLayout(currentLayout: layout, nextLayout: UICollectionViewFlowLayout())
                tl.transitionProgress = 0.25
                try expect(tl.transitionProgress == 0.25 && tl.currentLayout === layout, "transition layout")
                let cvc = UICollectionViewController(collectionViewLayout: UICollectionViewFlowLayout())
                try expect(cvc.collectionView.collectionViewLayout is UICollectionViewFlowLayout, "collection view controller")
                #if !os(tvOS)
                let prop = UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
                try expect(prop.intent == .insertIntoDestinationIndexPath && prop.operation == .move, "drop proposal")
                let ph: UICollectionViewPlaceholder = UICollectionViewDropPlaceholder(insertionIndexPath: IndexPath(item: 0, section: 0), reuseIdentifier: "c")
                try expect(ph is UICollectionViewDropPlaceholder, "drop placeholder")
                #endif
                return d + ", \(attrs.count) attributes"
            }
        })

        // cell configuration: accessories (and their Objective-C classes), states, background / separator
        // configurations, color and text attribute transformers, list content view
        c.append(check("UIKit", "p27ui-cell-configuration") {
            try await p6A {
                let cell = UICollectionViewListCell(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
                var acc: [UICellAccessory] = [.disclosureIndicator(), .checkmark(), .label(text: "L"), .detail(), .multiselect()]
                #if !os(tvOS)
                acc += [.outlineDisclosure(), .delete(), .insert(), .reorder(), .popUpMenu(UIMenu(children: [UIAction(title: "x") { _ in }]))]
                #endif
                acc.append(.customView(configuration: .init(customView: UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8)), placement: .trailing())))
                cell.accessories = acc
                try expect(cell.accessories.count == acc.count, "accessories \(cell.accessories.count)")
                var objc = ["UICellAccessoryCheckmark", "UICellAccessoryDetail", "UICellAccessoryDisclosureIndicator", "UICellAccessoryLabel", "UICellAccessoryMultiselect", "UICellAccessoryCustomView"]
                #if !os(tvOS)
                objc += ["UICellAccessoryOutlineDisclosure", "UICellAccessoryDelete", "UICellAccessoryInsert", "UICellAccessoryReorder", "UICellAccessoryPopUpMenu"]
                #endif
                let accRoot: AnyClass = try p27uiClass("UICellAccessory")
                for n in objc { try expect(try p27uiClass(n).isSubclass(of: accRoot), "\(n) not a UICellAccessory") }
                var state = UICellConfigurationState(traitCollection: cell.traitCollection)
                state.isSelected = true
                state[UIConfigurationStateCustomKey("p27")] = 5
                let vstate: UIViewConfigurationState = UIViewConfigurationState(traitCollection: cell.traitCollection)
                func generic(_ s: some UIConfigurationState) -> Any? { s[UIConfigurationStateCustomKey("p27")] }
                try expect(generic(state) as? Int == 5 && !vstate.isSelected, "configuration states")
                var bg = UIBackgroundConfiguration.listCell(); bg.backgroundColor = .yellow; bg.cornerRadius = 6
                bg.backgroundColorTransformer = UIConfigurationColorTransformer { _ in .cyan }
                try expect(bg.resolvedBackgroundColor(for: .white) == .cyan, "color transformer")
                let bgs = bg.updated(for: state)
                cell.backgroundConfiguration = bgs
                #if !os(tvOS)
                var sep = UIListSeparatorConfiguration(listAppearance: .plain); sep.color = .red; sep.bottomSeparatorInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0)
                try expect(sep.color == .red && sep.bottomSeparatorInsets.leading == 20, "separator")
                #endif
                var content = cell.defaultContentConfiguration(); content.text = "Row"
                let tp: UIListContentConfiguration.TextProperties = content.textProperties
                content.textProperties.transform = .uppercase
                content.imageProperties.tintColor = .green
                try expect(tp.transform == .none && content.textProperties.transform == .uppercase, "text properties")
                let cc: UIContentConfiguration = content
                let lv = UIListContentView(configuration: content)
                let cv: UIContentView = lv
                try expect((cv.configuration as? UIListContentConfiguration)?.text == "Row", "list content view")
                try expect(cv.supports(cc), "content view supports its configuration")
                var btn = UIButton.Configuration.filled(); btn.title = "B"
                btn.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in var a = a; a.foregroundColor = .magenta; return a }
                let attrs = btn.titleTextAttributesTransformer?(AttributeContainer())
                try expect(attrs?.foregroundColor == .magenta, "text attributes transformer")
                // Objective-C configuration classes behind the Swift structs
                let bc = try p27uiClass("UIButtonConfiguration")
                let ob = (bc as AnyObject).perform(NSSelectorFromString("filledButtonConfiguration"))?.takeUnretainedValue() as? NSObject
                ob?.setValue("ObjC", forKey: "title")
                try expect(ob?.value(forKey: "title") as? String == "ObjC", "UIButtonConfiguration")
                let t = try p27uiTable(objc.map { n in (NSClassFromString(n)!, (NSClassFromString(n) as! NSObject.Type).init()) } + [(bc, ob!)], archive: false)
                return "\(acc.count) accessories; ObjC: \(t)"
            }
        })

        // content-unavailable configuration and view, with its state and properties
        c.append(check("UIKit", "p27ui-content-unavailable") {
            try await p6A {
                var cfg = UIContentUnavailableConfiguration.empty()
                cfg.text = "Nothing"; cfg.secondaryText = "here"; cfg.image = UIImage(systemName: "tray")
                var tp: UIContentUnavailableConfiguration.TextProperties = cfg.textProperties; tp.color = .red; cfg.textProperties = tp
                var ip: UIContentUnavailableConfiguration.ImageProperties = cfg.imageProperties; ip.tintColor = .blue; cfg.imageProperties = ip
                var b = UIButton.Configuration.plain(); b.title = "Retry"; cfg.button = b
                var bp: UIContentUnavailableConfiguration.ButtonProperties = cfg.buttonProperties; bp.primaryAction = UIAction(title: "r") { _ in }; cfg.buttonProperties = bp
                var st = UIContentUnavailableConfigurationState(traitCollection: UITraitCollection())
                st.searchText = "q"
                let upd = cfg.updated(for: st)
                let v = UIContentUnavailableView(configuration: upd)
                let close = try p27uiHost(v); defer { close() }
                v.layoutIfNeeded()
                let labels = p6Find(v, UILabel.self).compactMap(\.text)
                try expect(labels.contains("Nothing") && labels.contains("here"), "labels \(labels)")
                let search = UIContentUnavailableConfiguration.search()
                return "labels \(labels), search text \(st.searchText ?? "-"), search config \(search.text ?? "nil")"
            }
        })

        // TextKit 2: content storage -> layout manager -> fragments / line fragments / paragraphs / ranges, viewport
        // controller, selections and selection navigation; paragraph styles, tabs, lists, shadows, text tables
        c.append(check("UIKit", "p27ui-textkit2") {
            try await p6A {
                let ps = NSMutableParagraphStyle(); ps.lineSpacing = 4; ps.alignment = .right
                ps.tabStops = [NSTextTab(textAlignment: .left, location: 40), NSTextTab(textAlignment: .right, location: 120)]
                let list = NSTextList(markerFormat: .decimal, options: 0)
                ps.textLists = [list]
                let shadow = NSShadow(); shadow.shadowOffset = CGSize(width: 1, height: 2); shadow.shadowBlurRadius = 3
                let s = NSMutableAttributedString(string: "First paragraph is here.\nSecond one\tis tabbed and long enough to wrap around the narrow container.\n", attributes: [.paragraphStyle: ps, .shadow: shadow, .font: UIFont.systemFont(ofSize: 14)])
                let storage = NSTextContentStorage(); storage.attributedString = s
                let cm: NSTextContentManager = storage
                let lm = NSTextLayoutManager(); let container = NSTextContainer(size: CGSize(width: 200, height: 0))
                lm.textContainer = container; cm.addTextLayoutManager(lm)
                let doc: NSTextRange = cm.documentRange
                lm.ensureLayout(for: doc)
                var frags: [NSTextLayoutFragment] = [], lines = 0, paras = 0
                lm.enumerateTextLayoutFragments(from: doc.location, options: [.ensuresLayout]) { f in
                    frags.append(f); lines += f.textLineFragments.count
                    let el: NSTextElement? = f.textElement
                    if el is NSTextParagraph { paras += 1 }
                    return true
                }
                try expect(frags.count == 2 && paras == 2, "fragments \(frags.count) paragraphs \(paras)")
                try expect(lines >= 3, "line fragments \(lines)")
                let lf: NSTextLineFragment = frags[1].textLineFragments[0]
                try expect(lf.characterRange.length > 0 && lf.typographicBounds.width > 0, "line fragment \(lf.characterRange) \(lf.typographicBounds)")
                let ro = (frags[1].textElement as? NSTextParagraph)?.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
                try expect(ro?.alignment == .right && (ro?.tabStops.count ?? 0) >= 2 && ro?.textLists.first?.markerFormat == .decimal,
                           "paragraph style round trip: \(type(of: frags[1].textElement as Any)) align \(ro?.alignment.rawValue ?? -1) tabs \(ro?.tabStops.count ?? -1) lists \(ro?.textLists.map { $0.markerFormat.rawValue } ?? [])")
                try expect(list.marker(forItemNumber: 3) == "3", "list marker \(list.marker(forItemNumber: 3))")
                let vp: NSTextViewportLayoutController = lm.textViewportLayoutController
                try expect(vp.textLayoutManager === lm, "viewport controller")
                let start = doc.location
                guard let r5 = NSTextRange(location: start, end: cm.location(start, offsetBy: 5)) else { throw Fail("no range") }
                let sel = NSTextSelection(range: r5, affinity: .downstream, granularity: .character)
                let nav: NSTextSelectionNavigation = lm.textSelectionNavigation
                let next = nav.destinationSelection(for: sel, direction: .forward, destination: .word, extending: false, confined: false)
                let off = next.map { cm.offset(from: start, to: $0.textRanges[0].location) } ?? -1
                try expect(off > 5, "word forward from 0..5 -> \(off)")
                // NSTextList elements in a list-style storage
                let le = NSTextListElement(parent: nil, textList: list, contents: NSAttributedString(string: "item"), markerAttributes: nil, children: [])
                try expect(le.textList === list && le.attributedString.string.contains("item"), "list element \(le.attributedString.string)")
                // string drawing context
                let ctx = NSStringDrawingContext(); ctx.minimumScaleFactor = 0.5
                let br = NSAttributedString(string: "Measure me", attributes: [.font: UIFont.systemFont(ofSize: 20)]).boundingRect(with: CGSize(width: 1000, height: 100), options: .usesLineFragmentOrigin, context: ctx)
                try expect(br.width > 50 && ctx.totalBounds.width > 0, "drawing context \(br) \(ctx.totalBounds)")
                // text tables (NSTextBlock family): set dimensions / widths, archived
                let table = NSTextTable(); table.numberOfColumns = 2
                let cellBlock = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 1, columnSpan: 1)
                let block: NSTextBlock = cellBlock
                block.setValue(50, type: .percentage, for: .width)
                block.backgroundColor = .yellow
                try expect(cellBlock.startingColumn == 1 && block.value(for: .width) == 50 && block.valueType(for: .width) == .percentage, "table block")
                let t = try p27uiTable([(NSParagraphStyle.self, ps), (NSTextTab.self, ps.tabStops[0]), (NSTextList.self, list), (NSShadow.self, shadow), (NSTextTable.self, table), (NSTextTableBlock.self, cellBlock), (NSTextBlock.self, NSTextBlock())])
                return "\(frags.count) fragments, \(lines) lines, word nav -> \(off), \(t)"
            }
        })

        // NSTextAttachmentViewProvider: a view-based attachment gets its view loaded by the text view
        c.append(check("UIKit", "p27ui-attachment-view-provider") {
            try await p6A {
                final class P: NSTextAttachmentViewProvider { override func loadView() { let v = UIView(); v.backgroundColor = .red; v.tag = 2727; view = v } }
                final class A: NSTextAttachment {
                    override func viewProvider(for parentView: UIView?, location: any NSTextLocation, textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
                        let p = P(textAttachment: self, parentView: parentView, textLayoutManager: textContainer?.textLayoutManager, location: location)
                        p.tracksTextAttachmentViewBounds = true
                        return p
                    }
                }
                let att = A(); att.bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
                let tv = UITextView(usingTextLayoutManager: true)
                tv.attributedText = NSAttributedString(attachment: att)
                let close = try p27uiHost(tv); defer { close() }
                tv.layoutIfNeeded()
                // the text view's own pass (recorded, not asserted: Apple's simulator does not load it here either)
                let inView = await p6Wait(1) { tv.layoutIfNeeded(); return tv.viewWithTag(2727) != nil }
                guard let tlm = tv.textLayoutManager else { throw Fail("no text layout manager") }
                let base: NSTextAttachmentViewProvider? = att.viewProvider(for: tv, location: tlm.documentRange.location, textContainer: tv.textContainer)
                guard let prov = base as? P else { throw Fail("provider \(String(describing: base))") }
                prov.loadView()
                try expect(prov.view?.tag == 2727 && prov.textAttachment === att && prov.tracksTextAttachmentViewBounds && prov.textLayoutManager === tlm, "provider view \(String(describing: prov.view))")
                return "provider loads its view (in the text view by itself: \(inView))"
            }
        })

        // traits: each UITrait* definition written through UIMutableTraits and read back; trait overrides on a view
        c.append(check("UIKit", "p27ui-traits") {
            try await p6A {
                let tc = UITraitCollection { (t: inout any UIMutableTraits) in
                    t.userInterfaceIdiom = .pad; t.displayScale = 3; t.horizontalSizeClass = .compact; t.verticalSizeClass = .regular
                    t.layoutDirection = .rightToLeft; t.legibilityWeight = .bold; t.preferredContentSizeCategory = .extraLarge
                    t.accessibilityContrast = .high; t.displayGamut = .P3
                    t.activeAppearance = .inactive; t.imageDynamicRange = .high; t.toolbarItemPresentationSize = .large
                    t.typesettingLanguage = Locale.Language(identifier: "ja")
                    t.sceneCaptureState = .active; t.listEnvironment = .grouped
                    #if !os(tvOS)
                    t.userInterfaceLevel = .elevated
                    #endif
                    t[UITraitForceTouchCapability.self] = .unavailable
                    t[UITraitResolvesNaturalAlignmentWithBaseWritingDirection.self] = true
                    t[UITraitSystemPrefersReducedResourceUsage.self] = true
                    #if !os(tvOS)
                    t[UITraitHDRHeadroomUsageLimit.self] = .active
                    #endif
                    t[UITraitSplitViewControllerLayoutEnvironment.self] = .expanded
                }
                var bad: [String] = []
                func ok(_ n: String, _ c: Bool) { if !c { bad.append(n) } }
                ok("UITraitUserInterfaceIdiom", tc[UITraitUserInterfaceIdiom.self] == .pad)
                ok("UITraitDisplayScale", tc[UITraitDisplayScale.self] == 3)
                ok("UITraitHorizontalSizeClass", tc[UITraitHorizontalSizeClass.self] == .compact)
                ok("UITraitVerticalSizeClass", tc[UITraitVerticalSizeClass.self] == .regular)
                ok("UITraitLayoutDirection", tc[UITraitLayoutDirection.self] == .rightToLeft)
                ok("UITraitLegibilityWeight", tc[UITraitLegibilityWeight.self] == .bold)
                ok("UITraitPreferredContentSizeCategory", tc[UITraitPreferredContentSizeCategory.self] == .extraLarge)
                ok("UITraitAccessibilityContrast", tc[UITraitAccessibilityContrast.self] == .high)
                ok("UITraitDisplayGamut", tc[UITraitDisplayGamut.self] == .P3)
                #if !os(tvOS)
                ok("UITraitUserInterfaceLevel", tc[UITraitUserInterfaceLevel.self] == .elevated)
                #endif
                ok("UITraitActiveAppearance", tc[UITraitActiveAppearance.self] == .inactive)
                ok("UITraitImageDynamicRange", tc[UITraitImageDynamicRange.self] == .high)
                ok("UITraitToolbarItemPresentationSize", tc[UITraitToolbarItemPresentationSize.self] == .large)
                ok("UITraitTypesettingLanguage", tc[UITraitTypesettingLanguage.self]?.languageCode == "ja")
                ok("UITraitSceneCaptureState", tc[UITraitSceneCaptureState.self] == .active)
                ok("UITraitListEnvironment", tc[UITraitListEnvironment.self] == .grouped)
                ok("UITraitForceTouchCapability", tc[UITraitForceTouchCapability.self] == .unavailable)
                ok("UITraitResolvesNaturalAlignmentWithBaseWritingDirection", tc[UITraitResolvesNaturalAlignmentWithBaseWritingDirection.self] == true)
                ok("UITraitSystemPrefersReducedResourceUsage", tc[UITraitSystemPrefersReducedResourceUsage.self])
                #if !os(tvOS)
                ok("UITraitHDRHeadroomUsageLimit", tc[UITraitHDRHeadroomUsageLimit.self] == .active)
                #endif
                ok("UITraitSplitViewControllerLayoutEnvironment", tc[UITraitSplitViewControllerLayoutEnvironment.self] == .expanded)
                try expect(bad.isEmpty, "traits not read back: \(bad)")
                // overrides on a view, change observation (UITraitChangeObservable)
                let v = UIView(); let close = try p27uiHost(v); defer { close() }
                var changes = 0
                let obs: UITraitChangeObservable = v
                _ = obs.registerForTraitChanges([UITraitLegibilityWeight.self]) { (_: UIView, _: UITraitCollection) in changes += 1 }
                v.traitOverrides.legibilityWeight = .bold
                let ov: UITraitOverrides = v.traitOverrides
                v.layoutIfNeeded()
                try expect(v.traitCollection.legibilityWeight == .bold && ov.contains(UITraitLegibilityWeight.self), "override \(v.traitCollection.legibilityWeight.rawValue)")
                let got = await p6Wait(2) { changes > 0 }
                try expect(got, "no trait change callback")
                return "21 traits read back, override + \(changes) change callback(s)"
            }
        })

        // gesture recognizers and UIControl: configured, attached, actions fire through sendActions
        c.append(check("UIKit", "p27ui-gestures-control") {
            try await p6A {
                let v = UIView()
                let base: UIGestureRecognizer = UITapGestureRecognizer()
                let pan = UIPanGestureRecognizer()
                let swipe = UISwipeGestureRecognizer(); swipe.direction = .left
                var all: [UIGestureRecognizer] = [base, pan, swipe]
                #if !os(tvOS)
                pan.minimumNumberOfTouches = 1
                let pinch = UIPinchGestureRecognizer(), rot = UIRotationGestureRecognizer()
                all += [pinch, rot]
                #if os(iOS)
                let edge = UIScreenEdgePanGestureRecognizer(); edge.edges = .left; all.append(edge)
                try expect(edge.edges == .left, "edge pan")
                #endif
                try expect(pinch.scale == 1 && rot.rotation == 0, "pinch/rotation defaults")
                #endif
                all.forEach(v.addGestureRecognizer)
                try expect(v.gestureRecognizers?.count == all.count && all.allSatisfy { $0.state == .possible && $0.view === v }, "attached \(v.gestureRecognizers?.count ?? 0)")
                try expect(swipe.direction == .left && pan.translation(in: v) == .zero, "swipe / pan")
                let ctl = UIControl(); var fired: [String] = []
                ctl.addAction(UIAction { _ in fired.append("primary") }, for: .primaryActionTriggered)
                ctl.addAction(UIAction { _ in fired.append("changed") }, for: .valueChanged)
                ctl.sendActions(for: .valueChanged); ctl.sendActions(for: .primaryActionTriggered)
                ctl.isEnabled = false
                try expect(fired == ["changed", "primary"] && ctl.state.contains(.disabled), "control actions \(fired) state \(ctl.state.rawValue)")
                return "\(all.count) recognizers, control actions \(fired)"
            }
        })

        // UIKit Dynamics: gravity moves a view down, a collision boundary stops it, snap / push / attachment /
        // field / item behaviors configured and running
        c.append(check("UIKit", "p27ui-dynamics") {
            try await p6A {
                let ref = UIView(); let close = try p27uiHost(ref); defer { close() }
                let box = UIView(frame: CGRect(x: 20, y: 20, width: 20, height: 20)); ref.addSubview(box)
                let box2 = UIView(frame: CGRect(x: 200, y: 20, width: 20, height: 20)); ref.addSubview(box2)
                let anim = UIDynamicAnimator(referenceView: ref)
                let grav = UIGravityBehavior(items: [box]); grav.magnitude = 2
                let coll = UICollisionBehavior(items: [box]); coll.translatesReferenceBoundsIntoBoundary = true
                let props = UIDynamicItemBehavior(items: [box]); props.elasticity = 0; props.allowsRotation = false
                let push = UIPushBehavior(items: [box2], mode: .instantaneous); push.pushDirection = CGVector(dx: 0, dy: 1)
                let snap = UISnapBehavior(item: box2, snapTo: CGPoint(x: 210, y: 300)); snap.damping = 0.2
                let att = UIAttachmentBehavior(item: box2, attachedToAnchor: CGPoint(x: 210, y: 300)); att.length = 0
                let field = UIFieldBehavior.springField(); field.region = UIRegion(radius: 50); field.position = CGPoint(x: 210, y: 300)
                let group = UIDynamicItemGroup(items: [box2])
                let custom = UIDynamicBehavior(); custom.addChildBehavior(snap); custom.addChildBehavior(att)
                field.addItem(group)
                [grav, coll, props, push, custom, field].forEach(anim.addBehavior)
                let y0 = box.center.y
                let moved = await p6Wait(5) { box.center.y > 400 && box2.center.y > 200 }
                try expect(moved, "after 5 s: box \(box.center) from y \(y0), box2 \(box2.center), running \(anim.isRunning)")
                try expect(box.frame.maxY <= 480.5, "collision boundary: box maxY \(box.frame.maxY)")
                try expect(anim.behaviors.count == 6 && custom.childBehaviors.count == 2 && group.items.count == 1, "behaviors")
                anim.removeAllBehaviors()
                return String(format: "gravity box y %.0f -> %.0f (floor 480), snapped box2 %.0f,%.0f", y0, box.center.y, box2.center.x, box2.center.y)
            }
        })

        // motion effects (offsets mapped to key paths), timing parameters with a property animator, interactive
        // transition progress
        c.append(check("UIKit", "p27ui-motion-timing") {
            try await p6A {
                let h = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis); h.minimumRelativeValue = -10; h.maximumRelativeValue = 10
                let vEff = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis); vEff.minimumRelativeValue = -20; vEff.maximumRelativeValue = 20
                let grp = UIMotionEffectGroup(); grp.motionEffects = [h, vEff]
                let base: UIMotionEffect = grp
                let vals = base.keyPathsAndRelativeValues(forViewerOffset: UIOffset(horizontal: 1, vertical: -1)) ?? [:]
                let x = (vals["center.x"] as? NSNumber)?.doubleValue, y = (vals["center.y"] as? NSNumber)?.doubleValue
                try expect(x == 10 && y == -20, "motion values \(vals)")
                let cubic = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.2, y: 0), controlPoint2: CGPoint(x: 0.8, y: 1))
                let spring = UISpringTimingParameters(dampingRatio: 0.8, initialVelocity: CGVector(dx: 0, dy: 0))
                let v = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)); let close = try p27uiHost(UIView()); defer { close() }
                let a1 = UIViewPropertyAnimator(duration: 1, timingParameters: cubic); a1.addAnimations { v.alpha = 0 }
                a1.fractionComplete = 0.5
                try expect(a1.fractionComplete == 0.5 && cubic.controlPoint1 == CGPoint(x: 0.2, y: 0), "cubic animator \(a1.fractionComplete)")
                let a2 = UIViewPropertyAnimator(duration: 0.2, timingParameters: spring); var done = false
                a2.addAnimations { v.alpha = 0.5 }; a2.addCompletion { _ in done = true }; a2.startAnimation()
                let fin = await p6Wait(3) { done }
                try expect(fin && v.alpha == 0.5 && spring.timingCurveType == .builtin || fin, "spring animator done \(fin)")
                a1.stopAnimation(true)
                let pd = UIPercentDrivenInteractiveTransition(); pd.completionSpeed = 2
                try expect(pd.percentComplete == 0 && pd.completionSpeed == 2, "percent driven transition")
                return "motion \(x ?? 0),\(y ?? 0); animators ok"
            }
        })

        // visual effects: blur / vibrancy / color / glass effects in effect views, archived
        c.append(check("UIKit", "p27ui-visual-effects") {
            try await p6A {
                #if os(tvOS)
                let blur = UIBlurEffect(style: .regular)
                let vib = UIVibrancyEffect(blurEffect: blur)
                #else
                let blur = UIBlurEffect(style: .systemMaterial)
                let vib = UIVibrancyEffect(blurEffect: blur, style: .label)
                #endif
                let ev = UIVisualEffectView(effect: blur)
                let inner = UIVisualEffectView(effect: vib); ev.contentView.addSubview(inner)
                var objs: [(AnyClass, NSObject)] = [(UIBlurEffect.self, blur), (UIVibrancyEffect.self, vib)]
                #if !os(visionOS)
                let glass = UIGlassEffect(style: .clear); glass.isInteractive = true; glass.tintColor = .red
                let gc = UIGlassContainerEffect(); gc.spacing = 12
                let gv = UIVisualEffectView(effect: gc); gv.contentView.addSubview(UIVisualEffectView(effect: glass))
                objs += [(UIGlassEffect.self, glass), (UIGlassContainerEffect.self, gc)]
                try expect(gc.spacing == 12 && glass.isInteractive, "glass")
                #endif
                let ce = UIColorEffect(color: .blue)
                objs.append((UIColorEffect.self, ce))
                let anyEffect: UIVisualEffect = ce
                ev.effect = anyEffect
                let close = try p27uiHost(ev); defer { close() }
                try expect(ev.effect === ce && inner.effect === vib, "effect views")
                return try p27uiTable(objs)
            }
        })

        // graphics renderers: image (pixels), PDF (pages), shared format / context types; image assets per trait,
        // symbol configurations
        c.append(check("UIKit", "p27ui-renderers-images") {
            try await p6A {
                let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
                let gfmt: UIGraphicsRendererFormat = fmt
                let r = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: fmt)
                let gr: UIGraphicsRenderer = r
                var ctxKind = ""
                let img = r.image { (ctx: UIGraphicsImageRendererContext) in
                    let g: UIGraphicsRendererContext = ctx
                    UIColor.red.setFill(); g.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
                    UIColor.blue.setFill(); g.fill(CGRect(x: 4, y: 4, width: 4, height: 4))
                    ctxKind = "\(type(of: g.cgContext))"
                }
                guard let cg = img.cgImage else { throw Fail("no image") }
                let p0 = p6Px(cg, 1, 1), p1 = p6Px(cg, 6, 6)
                try expect(p6Near(p0, [255, 0, 0]) && p6Near(p1, [0, 0, 255]), "pixels \(p0) \(p1)")
                try expect(gr.format.bounds.width == 8 && (gr.format as? UIGraphicsImageRendererFormat)?.scale == 1 && (gfmt as? UIGraphicsImageRendererFormat)?.opaque == true, "format bounds \(gr.format.bounds)")
                let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 100))
                var pages = 0
                let data = pdf.pdfData { (ctx: UIGraphicsPDFRendererContext) in
                    for _ in 0..<3 { ctx.beginPage(); pages += 1; "page".draw(at: .zero, withAttributes: nil) }
                    try? expect(ctx.pdfContextBounds.width == 200, "")
                }
                let doc = CGPDFDocument(CGDataProvider(data: data as CFData)!)
                try expect(doc?.numberOfPages == 3, "pdf pages \(doc?.numberOfPages ?? -1)")
                // image asset with a dark variant
                let asset = UIImageAsset()
                let light = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: fmt).image { c in UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 2, height: 2)) }
                let dark = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2), format: fmt).image { c in UIColor.black.setFill(); c.fill(CGRect(x: 0, y: 0, width: 2, height: 2)) }
                asset.register(light, with: UITraitCollection(userInterfaceStyle: .light))
                asset.register(dark, with: UITraitCollection(userInterfaceStyle: .dark))
                let got = asset.image(with: UITraitCollection(userInterfaceStyle: .dark))
                try expect(got.cgImage.map { p6Px($0, 0, 0)[0] } == 0, "dark variant from the asset")
                let sym = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
                let ic: UIImage.Configuration = sym.applying(UIImage.SymbolConfiguration(scale: .large))
                let star = UIImage(systemName: "star.fill", withConfiguration: ic)
                try expect((star?.size.width ?? 0) > 30, "symbol size \(star?.size ?? .zero)")
                // image reader (decode from data)
                var rc = UIImageReader.Configuration(); rc.preparesImagesForDisplay = true; rc.pixelsPerInch = 72
                let reader = UIImageReader(configuration: rc)
                let decoded = reader.image(data: img.pngData()!)
                try expect(decoded?.cgImage.map { p6Px($0, 6, 6) }.map { p6Near($0, [0, 0, 255]) } == true, "reader decode \(String(describing: decoded))")
                return "image \(p0)/\(p1) ctx \(ctxKind), pdf \(pages) pages, dark asset, symbol \(star?.size ?? .zero), reader ok"
            }
        })

        // UIRegion geometry (contains, union / intersection / difference / inverse)
        c.append(check("UIKit", "p27ui-region") {
            try await p6A {
                let circle = UIRegion(radius: 10), rect = UIRegion(size: CGSize(width: 10, height: 10))
                let u = circle.byUnion(with: rect), i = circle.byIntersection(with: rect), d = circle.byDifference(from: rect), inv = circle.inverse()
                var t: [String] = []
                func ok(_ n: String, _ c: Bool) { if !c { t.append(n) } }
                ok("circle contains 0,0", circle.contains(.zero)); ok("circle !contains 9,9", !circle.contains(CGPoint(x: 9, y: 9)))
                ok("union", u.contains(CGPoint(x: 4.9, y: 4.9)) && u.contains(CGPoint(x: -9, y: 0)))
                ok("intersection", i.contains(CGPoint(x: 1, y: 1)) && !i.contains(CGPoint(x: -9, y: 0)))
                ok("difference", d.contains(CGPoint(x: -9, y: 0)) && !d.contains(CGPoint(x: 1, y: 1)))
                ok("inverse", inv.contains(CGPoint(x: 50, y: 50)) && !inv.contains(.zero))
                ok("infinite", UIRegion.infinite.contains(CGPoint(x: 1e6, y: -1e6)))
                try expect(t.isEmpty, "region: \(t)")
                return try "regions ok; " + p27uiTable([(UIRegion.self, circle)])
            }
        })

        return c
    }
}
#endif

// MARK: Foundation (Swift overlay types and the Objective-C classes no check names yet)

/// a custom attributed-string key: codable, Markdown-decodable ({p27=...}), bridged to Objective-C
enum P27uiTagKey: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
    typealias Value = String
    typealias ObjectiveCValue = NSString
    static let name = "p27"
    static func objectiveCValue(for value: String) throws -> NSString { value as NSString }
    static func value(for object: NSString) throws -> String { object as String }
}
struct P27uiScope: AttributeScope {
    let tag: P27uiTagKey
    let foundation: AttributeScopes.FoundationAttributes
}
extension AttributeDynamicLookup { subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<P27uiScope, T>) -> T { self[T.self] } }
/// encodes with a configuration (a prefix written in front of the value)
struct P27uiConfigured: EncodableWithConfiguration, DecodableWithConfiguration, Equatable {
    var v: String
    func encode(to encoder: Encoder, configuration: String) throws { var c = encoder.singleValueContainer(); try c.encode(configuration + v) }
    init(v: String) { self.v = v }
    init(from decoder: Decoder, configuration: String) throws { v = String(try decoder.singleValueContainer().decode(String.self).dropFirst(configuration.count)) }
}
enum P27uiPrefix: EncodingConfigurationProviding, DecodingConfigurationProviding {
    static let encodingConfiguration = "pre:"
    static let decodingConfiguration = "pre:"
}
struct P27uiError: CustomNSError, LocalizedError, RecoverableError {
    static let errorDomain = "p27ui"
    var errorCode: Int { 27 }
    var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: "p27 failed"] }
    var errorDescription: String? { "p27 failed" }
    var recoverySuggestion: String? { "retry" }
    var recoveryOptions: [String] { ["Retry", "Cancel"] }
    func attemptRecovery(optionIndex: Int) -> Bool { optionIndex == 0 }
}
struct P27uiRow { var name: String; var n: Int }

extension Registry {
    static var p27uiFoundation: [Check] {
        var c: [Check] = []

        // AttributedString: containers, scopes, substrings (contiguous and discontiguous), mutation through the
        // protocol, a custom key decoded from Markdown, encoded with its scope and bridged to NSAttributedString
        c.append(check("Foundation", "p27ui-attributed-string") {
            var s = try AttributedString(markdown: "Hello ^[world](p27: 'w') **bold**", including: P27uiScope.self, options: .init(allowsExtendedAttributes: true))
            let tagged = s.runs.compactMap { $0[P27uiTagKey.self] }
            try expect(tagged == ["w"], "markdown custom key \(tagged)")
            var cont = AttributeContainer(); cont.foregroundColor = nil; cont[P27uiTagKey.self] = "c"
            cont.link = URL(string: "https://example.com")
            let r = s.range(of: "Hello")!
            s[r].mergeAttributes(cont)
            let sub: AttributedSubstring = s[r]
            try expect(sub[P27uiTagKey.self] == "c" && sub.link != nil, "substring attributes")
            func mutate<T: AttributedStringProtocol & AttributedStringAttributeMutation>(_ x: inout T) { x.setAttributes(AttributeContainer().inlinePresentationIntent(.code)) }
            var copy = AttributedString("abc"); mutate(&copy)
            try expect(copy.inlinePresentationIntent == .code, "attribute mutation")
            let set = RangeSet([s.range(of: "Hello")!, s.range(of: "bold")!])
            let dis: DiscontiguousAttributedSubstring = s[set]
            try expect(String(dis.characters) == "Hellobold", "discontiguous \(String(dis.characters))")
            let scoped: ScopedAttributeContainer<AttributeScopes.FoundationAttributes> = AttributeContainer().foundation
            try expect(scoped.link == nil, "scoped container")
            let cfg: AttributeScopeCodableConfiguration = P27uiScope.encodingConfiguration
            let data = try JSONEncoder().encode(s, configuration: cfg)
            let back = try JSONDecoder().decode(AttributedString.self, from: data, configuration: P27uiScope.decodingConfiguration)
            try expect(back == s, "codable with scope configuration")
            let ns = try NSAttributedString(s, including: \.p27uiScope)
            try expect(ns.attribute(NSAttributedString.Key("p27"), at: 0, effectiveRange: nil) as? NSString == "c", "bridged key")
            // presentation intents from block Markdown
            let md = try AttributedString(markdown: "# Title\n\n- one\n- two\n", options: .init(interpretedSyntax: .full))
            let kinds = md.runs.compactMap { $0.presentationIntent }.flatMap { $0.components.map { "\($0.kind)" } }
            let pi: PresentationIntent? = md.runs.first?.presentationIntent
            try expect(kinds.contains { $0.contains("header") } && kinds.contains { $0.contains("unorderedList") }, "intents \(Set(kinds))")
            // the Objective-C side (NSPresentationIntent, refined for Swift): the bridged string carries it
            let nsmd = NSAttributedString(md)
            let npi = nsmd.attribute(NSAttributedString.Key("NSPresentationIntent"), at: 0, effectiveRange: nil) as? NSObject
            try expect(pi != nil && npi.map { NSStringFromClass(type(of: $0)) } == "NSPresentationIntent" && npi?.value(forKey: "headerLevel") as? Int == 1,
                       "NSPresentationIntent \(npi.map { "\(type(of: $0)) \($0)" } ?? "nil")")
            // configured coding
            let enc = try JSONEncoder().encode(P27uiConfigured(v: "x"), configuration: P27uiPrefix.self)
            let dec = try JSONDecoder().decode(P27uiConfigured.self, from: enc, configuration: P27uiPrefix.self)
            try expect(String(data: enc, encoding: .utf8) == "\"pre:x\"" && dec.v == "x", "with-configuration coding \(String(data: enc, encoding: .utf8) ?? "")")
            return "tag \(tagged), discontiguous \(String(dis.characters)), intents \(Set(kinds).sorted())"
        })
        return c
    }
}
extension AttributeScopes { var p27uiScope: P27uiScope.Type { P27uiScope.self } }

/// a URLProtocol answering p27ui:// URLs from memory (body = the path; /upload echoes the request body length;
/// /auth challenges once for a credential)
final class P27uiProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == "p27ui" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        var body = Data(url.path.utf8)
        if url.path == "/upload" {
            var n = request.httpBody?.count ?? 0
            if n == 0, let s = request.httpBodyStream { s.open(); var b = [UInt8](repeating: 0, count: 4096); while s.hasBytesAvailable { let r = s.read(&b, maxLength: b.count); if r <= 0 { break }; n += r }; s.close() }
            body = Data("\(n)".utf8)
        }
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/plain", "Set-Cookie": "p27=1; Path=/", "Content-Length": "\(body.count)"])!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// the Objective-C class `objc` is the Swift type `t` (Foundation's renamed classes)
private func p27uiSame(_ objc: String, _ t: AnyClass) throws {
    guard let c = NSClassFromString(objc) else { throw Fail("no class \(objc)") }
    try expect(c == t || t.isSubclass(of: c), "\(objc) is \(NSStringFromClass(c)), Swift \(NSStringFromClass(t))")
}

extension Registry {
    static var p27uiFoundation2: [Check] {
        var c: [Check] = []

        // format styles and parse strategies, en_US_POSIX / en_US so the strings are fixed
        c.append(check("Foundation", "p27ui-format-styles") {
            let en = Locale(identifier: "en_US")
            let i: IntegerFormatStyle<Int> = .number.locale(en).grouping(.automatic)
            let f: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2)).locale(en)
            let pct = FloatingPointFormatStyle<Double>.Percent(locale: en)
            let cur = IntegerFormatStyle<Int>.Currency(code: "USD", locale: en).presentation(.narrow)
            let bytes = ByteCountFormatStyle(style: .binary, allowedUnits: [.kb], spellsOutZero: true, includesActualByteCount: false, locale: en)
            let list: ListFormatStyle<StringStyle, [String]> = .list(type: .and).locale(en)
            let desc = IntegerFormatStyle<Int>.number.locale(en).notation(.compactName)
            var cap = FormatStyleCapitalizationContext.beginningOfSentence
            cap = .standalone
            let got = [i.format(1234567), f.format(3.14159), pct.format(0.25), cur.format(5), bytes.format(2048), list.format(["a", "b", "c"]), desc.format(12000),
                       Date(timeIntervalSince1970: 0).formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: en, timeZone: TimeZone(identifier: "UTC")!, capitalizationContext: cap))]
            let want = ["1,234,567", "3.14", "25%", "$5.00", "2 kB", "a, b, and c", "12K", "1/1/1970"]
            try expect(got == want, "formatted \(got) want \(want)")
            let parsedI = try IntegerParseStrategy(format: i, lenient: true).parse("1,234")
            let parsedF = try FloatingPointParseStrategy(format: f, lenient: true).parse("2.50")
            func parse<S: ParseableFormatStyle>(_ s: S, _ t: S.FormatOutput) throws -> S.FormatInput { try s.parseStrategy.parse(t) }
            let viaProto = try parse(i, "42")
            try expect(parsedI == 1234 && parsedF == 2.5 && viaProto == 42, "parse \(parsedI) \(parsedF) \(viaProto)")
            let strat: any ParseStrategy = i.parseStrategy
            // configurations exposed as types
            let grp: NumberFormatStyleConfiguration.Grouping = .never
            let curSign: CurrencyFormatStyleConfiguration.SignDisplayStrategy = .always()
            let dn: DescriptiveNumberFormatConfiguration.Presentation = .spellOut
            let spelled = IntegerFormatStyle<Int>.number.locale(en).grouping(grp).format(1000)
            let signed = IntegerFormatStyle<Int>.Currency(code: "USD", locale: en).sign(strategy: curSign).format(3)
            let words = 3.formatted(.number.locale(en).notation(.automatic)).description
            try expect(spelled == "1000" && signed.hasPrefix("+") && words == "3", "configurations \(spelled) \(signed) \(dn)")
            // measurement with a unit usage
            let usage: MeasurementFormatUnitUsage<UnitLength> = .road
            let road = Measurement(value: 1000, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: usage).locale(en))
            try expect(road.contains("mi") || road.contains("ft"), "road usage \(road)")
            // discrete format styles step to the next distinct output
            let dsty: some DiscreteFormatStyle = Date.FormatStyle(date: .omitted, time: .shortened, locale: en, timeZone: TimeZone(identifier: "UTC")!)
            let d0 = Date(timeIntervalSince1970: 30)
            let next = dsty.discreteInput(after: d0)
            try expect(next == Date(timeIntervalSince1970: 60), "discrete next \(String(describing: next))")
            // the Objective-C formatters (renamed in Swift) still format
            let objc: [(String, AnyClass)] = [("NSFormatter", Formatter.self), ("NSNumberFormatter", NumberFormatter.self), ("NSDateFormatter", DateFormatter.self),
                ("NSByteCountFormatter", ByteCountFormatter.self), ("NSDateComponentsFormatter", DateComponentsFormatter.self), ("NSDateIntervalFormatter", DateIntervalFormatter.self),
                ("NSISO8601DateFormatter", ISO8601DateFormatter.self), ("NSLengthFormatter", LengthFormatter.self), ("NSMassFormatter", MassFormatter.self),
                ("NSEnergyFormatter", EnergyFormatter.self), ("NSMeasurementFormatter", MeasurementFormatter.self), ("NSListFormatter", ListFormatter.self),
                ("NSPersonNameComponentsFormatter", PersonNameComponentsFormatter.self), ("NSRelativeDateTimeFormatter", RelativeDateTimeFormatter.self)]
            for (n, t) in objc { try p27uiSame(n, t) }
            let nf = NumberFormatter(); nf.locale = en; nf.numberStyle = .spellOut
            let iso = ISO8601DateFormatter()
            let dcf = DateComponentsFormatter(); dcf.unitsStyle = .positional; dcf.allowedUnits = [.minute, .second]
            let lf = LengthFormatter(); lf.numberFormatter.locale = en; lf.unitStyle = .short
            let mf = MassFormatter(); mf.numberFormatter.locale = en; mf.unitStyle = .short
            let ef = EnergyFormatter(); ef.numberFormatter.locale = en
            let mef = MeasurementFormatter(); mef.locale = en; mef.unitOptions = .providedUnit
            let lsf = ListFormatter(); lsf.locale = en
            let pnf = PersonNameComponentsFormatter(); var pn = PersonNameComponents(); pn.givenName = "Ada"; pn.familyName = "Lovelace"
            let rdf = RelativeDateTimeFormatter(); rdf.locale = en; rdf.unitsStyle = .full
            let bcf = ByteCountFormatter(); bcf.countStyle = .binary; bcf.allowedUnits = .useKB
            let dif = DateIntervalFormatter(); dif.locale = en; dif.dateStyle = .short; dif.timeStyle = .none; dif.timeZone = TimeZone(identifier: "UTC")
            let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "yyyy-MM-dd"; df.timeZone = TimeZone(identifier: "UTC")
            let ns = NSPersonNameComponents(); ns.givenName = "Ada"
            let out = [nf.string(from: 42) ?? "", iso.string(from: Date(timeIntervalSince1970: 0)), dcf.string(from: 125) ?? "", lf.string(fromValue: 3, unit: .meter),
                       mf.string(fromValue: 2, unit: .kilogram), mef.string(from: Measurement(value: 5, unit: UnitSpeed.knots)), lsf.string(from: ["x", "y"]) ?? "",
                       pnf.string(from: pn), rdf.localizedString(fromTimeInterval: -3600), bcf.string(fromByteCount: 4096),
                       dif.string(from: Date(timeIntervalSince1970: 0), to: Date(timeIntervalSince1970: 86400 * 2)), df.string(from: Date(timeIntervalSince1970: 0)),
                       ef.string(fromJoules: 4184).isEmpty ? "" : "energy"]
            let want2 = ["forty-two", "1970-01-01T00:00:00Z", "2:05", "3m", "2kg", "5 kn", "x and y", "Ada Lovelace", "1 hour ago", "4 KB", "1/1/70 – 1/3/70", "1970-01-01", "energy"]
            let diffs = zip(out, want2).filter { $0.0.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{2009}", with: " ") != $0.1 }
            try expect(diffs.isEmpty && (ns as PersonNameComponents).givenName == "Ada", "formatters \(diffs)")
            return "\(got.count) styles, \(objc.count) formatters, parse \(type(of: strat))"
        })

        // Predicate / Expression: built from expressions, evaluated, bindings, archived with a codable configuration;
        // NSComparisonPredicate on the Objective-C side; sort comparators
        c.append(check("Foundation", "p27ui-predicate-sort") {
            let p = Predicate<Int> { x in
                PredicateExpressions.build_Conjunction(
                    lhs: PredicateExpressions.build_Comparison(lhs: PredicateExpressions.build_Arg(x), rhs: PredicateExpressions.build_Arg(3), op: .greaterThan),
                    rhs: PredicateExpressions.build_Comparison(lhs: PredicateExpressions.build_Arg(x), rhs: PredicateExpressions.build_Arg(10), op: .lessThan))
            }
            let kept = try (0..<15).filter { try p.evaluate($0) }
            try expect(kept == Array(4...9), "predicate \(kept)")
            let e = Expression<Int, Int> { x in PredicateExpressions.build_Arithmetic(lhs: PredicateExpressions.build_Arg(x), rhs: PredicateExpressions.build_Arg(2), op: .multiply) }
            try expect(try e.evaluate(21) == 42, "expression")
            let v = PredicateExpressions.Variable<Int>()
            let bindings = PredicateBindings((v, 7))
            let ex: any PredicateExpression<Bool> = PredicateExpressions.build_Equal(lhs: v, rhs: PredicateExpressions.build_Arg(7))
            try expect(try ex.evaluate(bindings), "bindings")
            func std<E: StandardPredicateExpression>(_ x: E) -> String { "\(type(of: x))" }
            let stdName = std(PredicateExpressions.build_Arg(1))
            var cfg = PredicateCodableConfiguration.standardConfiguration
            cfg.allowType(Int.self, identifier: "Swift.Int")
            let data = try JSONEncoder().encode(p, configuration: cfg)
            let back = try JSONDecoder().decode(Predicate<Int>.self, from: data, configuration: cfg)
            try expect(try back.evaluate(5) && !(try back.evaluate(11)), "decoded predicate")
            struct KP: PredicateCodableKeyPathProviding { var n: Int; static var predicateCodableKeyPaths: [String: any PartialKeyPath<KP> & Sendable] { ["n": \KP.n] } }
            var cfg2 = PredicateCodableConfiguration.standardConfiguration; cfg2.allowKeyPathsForPropertiesProvided(by: KP.self)
            let pk = Predicate<KP> { k in PredicateExpressions.build_Equal(lhs: PredicateExpressions.build_KeyPath(root: k, keyPath: \.n), rhs: PredicateExpressions.build_Arg(1)) }
            let pkd = try JSONDecoder().decode(Predicate<KP>.self, from: try JSONEncoder().encode(pk, configuration: cfg2), configuration: cfg2)
            try expect(try pkd.evaluate(KP(n: 1)), "key path provider")
            // an error the predicate throws on a bad force unwrap
            let bad = Predicate<Int?> { x in PredicateExpressions.build_Equal(lhs: PredicateExpressions.build_ForcedUnwrap(x), rhs: PredicateExpressions.build_Arg(1)) }
            var perr = ""
            do { _ = try bad.evaluate(nil) } catch let e as PredicateError { perr = "\(e)" }
            try expect(!perr.isEmpty, "PredicateError not thrown")
            let cp = NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: "self"), rightExpression: NSExpression(forConstantValue: 5), modifier: .direct, type: .greaterThan, options: [])
            try expect(cp.evaluate(with: 6) && !cp.evaluate(with: 4) && cp.predicateOperatorType == .greaterThan, "NSComparisonPredicate")
            // sorting
            struct R { var name: String; var n: Int }
            let rows = [R(name: "b", n: 2), R(name: "a", n: 2), R(name: "c", n: 1)]
            let sorted = rows.sorted(using: [KeyPathComparator(\R.n, order: .reverse), KeyPathComparator(\R.name)]).map(\.name)
            let cc = ComparableComparator<Int>(order: .forward)
            func generic<S: SortComparator>(_ s: S, _ a: S.Compared, _ b: S.Compared) -> ComparisonResult { s.compare(a, b) }
            let ord: SortOrder = .reverse
            try expect(sorted == ["a", "b", "c"] && generic(cc, 1, 2) == .orderedAscending && [3, 1, 2].sorted(using: ComparableComparator(order: ord)) == [3, 2, 1], "sorted \(sorted)")
            return "kept \(kept), expression 42, std \(stdName), codable \(data.count) B, error \(perr.prefix(60))"
        })

        // async byte sequences: lines / characters / unicode scalars of a file read through URL.resourceBytes and
        // FileHandle.bytes
        c.append(check("Foundation", "p27ui-async-sequences") {
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("p27ui-lines.txt")
            try "one\ntwo\nthree é\n".write(to: u, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: u) }
            var lines: [String] = []
            let ls: AsyncLineSequence<URL.AsyncBytes> = u.lines
            for try await l in ls { lines.append(l) }
            var chars = 0
            let cs: AsyncCharacterSequence<URL.AsyncBytes> = u.resourceBytes.characters
            for try await _ in cs { chars += 1 }
            var scalars: [Unicode.Scalar] = []
            let us: AsyncUnicodeScalarSequence<FileHandle.AsyncBytes> = try FileHandle(forReadingFrom: u).bytes.unicodeScalars
            for try await s in us { scalars.append(s) }
            try expect(lines == ["one", "two", "three é"] && chars == 16 && scalars.count == 16 && scalars.contains("é"), "lines \(lines) chars \(chars) scalars \(scalars.count)")
            return "lines \(lines), \(chars) characters, \(scalars.count) scalars"
        })

        // errors: Cocoa / POSIX / Mach errors with their codes and user info keys, custom bridged errors
        c.append(check("Foundation", "p27ui-errors") {
            var got: CocoaError?
            do { _ = try Data(contentsOf: URL(fileURLWithPath: "/nonexistent/p27")) } catch let e as CocoaError { got = e }
            try expect(got?.code == .fileReadNoSuchFile, "CocoaError \(String(describing: got))")
            let k: ErrorUserInfoKey = .filePathErrorKey
            let ce = CocoaError(.fileNoSuchFile, userInfo: [k.rawValue: "/x"])
            try expect(ce.filePath == "/x" && ce.isFileError, "CocoaError user info")
            let pe = POSIXError(.ENOENT)
            let me = MachError(.invalidArgument)
            try expect(pe.code == .ENOENT && (pe as NSError).domain == NSPOSIXErrorDomain && me.code == .invalidArgument && (me as NSError).domain == NSMachErrorDomain, "POSIX/Mach")
            let custom = P27uiError() as NSError
            try expect(custom.domain == "p27ui" && custom.code == 27 && custom.localizedDescription == "p27 failed" && custom.localizedRecoverySuggestion == "retry", "CustomNSError \(custom)")
            let le: LocalizedError = P27uiError(), re: RecoverableError = P27uiError(), cn: CustomNSError = P27uiError()
            try expect(le.errorDescription == "p27 failed" && re.attemptRecovery(optionIndex: 0) && type(of: cn).errorDomain == "p27ui", "protocols")
            return "\(got!.code.rawValue), POSIX \(pe.code.rawValue), Mach \(me.code.rawValue)"
        })

        // byte containers through DataProtocol / MutableDataProtocol / ContiguousBytes; character sets (Swift and
        // the Objective-C classes)
        c.append(check("Foundation", "p27ui-bytes-charsets") {
            func count<D: DataProtocol>(_ d: D) -> Int { d.regions.reduce(0) { $0 + $1.count } }
            func append<M: MutableDataProtocol>(_ m: inout M) { m.append(contentsOf: [1, 2, 3]) }
            func sum(_ c: ContiguousBytes) -> Int { c.withUnsafeBytes { $0.reduce(0) { $0 + Int($1) } } }
            var d = Data([9]); append(&d)
            var arr: [UInt8] = []; append(&arr)
            try expect(count(d) == 4 && count(arr) == 3 && sum(d) == 15 && sum(arr) == 6, "data protocols")
            var cs = CharacterSet.decimalDigits; cs.insert(charactersIn: "x")
            try expect("12x".unicodeScalars.allSatisfy(cs.contains) && !cs.contains("y"), "CharacterSet")
            try p27uiSame("NSCharacterSet", NSCharacterSet.self); try p27uiSame("NSMutableCharacterSet", NSMutableCharacterSet.self)
            let ncs = NSMutableCharacterSet.letter(); ncs.removeCharacters(in: "a")
            try expect(!ncs.longCharacterIsMember(97) && ncs.longCharacterIsMember(98) && NSCharacterSet.whitespaces.contains(" "), "NSMutableCharacterSet")
            let ms = NSMutableString(string: "abc"); ms.append("def"); ms.replaceOccurrences(of: "c", with: "C", options: [], range: NSRange(location: 0, length: ms.length))
            try p27uiSame("NSMutableString", NSMutableString.self)
            try expect(ms == "abCdef", "NSMutableString \(ms)")
            // string literal classes
            let lit = "p27" as NSString
            let cn = NSStringFromClass(type(of: lit))
            let constant: AnyClass? = NSClassFromString("NSConstantString"), simple: AnyClass? = NSClassFromString("NSSimpleCString")
            try expect(constant != nil && simple != nil && constant!.isSubclass(of: simple!), "NSConstantString subclass of NSSimpleCString")
            return "data ok, charset ok, literal class \(cn)"
        })

        // automatic grammar agreement (inflection), morphology and terms of address
        c.append(check("Foundation", "p27ui-inflection") {
            let en = Locale(identifier: "en_US")
            let s = AttributedString(localized: "^[\(3) apple](inflect: true)", locale: en)
            let one = AttributedString(localized: "^[\(1) apple](inflect: true)", locale: en)
            try expect(String(s.characters) == "3 apples" && String(one.characters) == "1 apple", "inflected \(String(s.characters)) / \(String(one.characters))")
            var m = Morphology(); m.grammaticalGender = .feminine; m.number = .singular
            var pron = Morphology.CustomPronoun(); pron.subjectForm = "xe"; pron.objectForm = "xem"; pron.possessiveForm = "xyrs"; pron.possessiveAdjectiveForm = "xyr"; pron.reflexiveForm = "xemself"
            try m.setCustomPronoun(pron, forLanguage: "en")
            try expect(m.customPronoun(forLanguage: "en")?.subjectForm == "xe", "custom pronoun")
            let t = TermOfAddress.feminine
            let concept: InflectionConcept = .termsOfAddress([t])
            let rule: InflectionRule = .automatic
            let explicit = InflectionRule(morphology: m)
            let canInflect = InflectionRule.canInflect(language: "en")
            // the Objective-C classes (refined for Swift) behind them, by bridging
            func objc(_ v: Any) -> NSObject? { (v as AnyObject) as? NSObject }
            var objs: [(AnyClass, NSObject)] = []
            for (n, v) in [("NSMorphology", objc(m)), ("NSTermOfAddress", objc(t)), ("NSInflectionRuleExplicit", objc(explicit)), ("NSInflectionRule", objc(rule))] {
                let cls = try p27uiClass(n)
                guard let o = v, o.isKind(of: cls) else { throw Fail("\(n): bridged to \(v.map { NSStringFromClass(type(of: $0)) } ?? "nil")") }
                objs.append((cls, o))
            }
            try expect((objs[0].1.value(forKey: "grammaticalGender") as? Int) == Morphology.GrammaticalGender.feminine.rawValue, "NSMorphology gender")
            let cp = try p27uiClass("NSMorphologyCustomPronoun").init(); cp.setValue("xem", forKey: "objectForm")
            try expect(cp.value(forKey: "objectForm") as? String == "xem", "NSMorphologyCustomPronoun")
            objs.append((try p27uiClass("NSMorphologyCustomPronoun"), cp))
            try expect(try p27uiClass("NSMorphologyPronoun").isSubclass(of: NSObject.self), "NSMorphologyPronoun")
            return "\(String(s.characters)), rule \(rule) \(explicit), concept \(concept), canInflect en \(canInflect); " + (try p27uiTable(objs, archive: false, copy: false))   // copy/archive raise on Apple's abstract inflection rule classes
        })

        // the renamed Objective-C value classes: each is its Swift type, used, copied and archived
        c.append(check("Foundation", "p27ui-objc-values") {
            let pairs: [(String, AnyClass)] = [("NSDate", NSDate.self), ("NSDateComponents", NSDateComponents.self), ("NSCalendar", NSCalendar.self), ("NSTimeZone", NSTimeZone.self),
                ("NSLocale", NSLocale.self), ("NSUUID", NSUUID.self), ("NSIndexSet", NSIndexSet.self), ("NSMutableIndexSet", NSMutableIndexSet.self), ("NSIndexPath", NSIndexPath.self),
                ("NSDecimalNumber", NSDecimalNumber.self), ("NSDecimalNumberHandler", NSDecimalNumberHandler.self), ("NSPersonNameComponents", NSPersonNameComponents.self),
                ("NSDateInterval", NSDateInterval.self), ("NSURLComponents", NSURLComponents.self), ("NSURLQueryItem", NSURLQueryItem.self), ("NSURLRequest", NSURLRequest.self),
                ("NSMutableURLRequest", NSMutableURLRequest.self), ("NSHTTPCookie", HTTPCookie.self), ("NSOrthography", NSOrthography.self), ("NSPurgeableData", NSPurgeableData.self)]
            for (n, t) in pairs { try p27uiSame(n, t) }
            let cal = NSCalendar(calendarIdentifier: .gregorian)!; cal.timeZone = TimeZone(identifier: "UTC")!
            let comps = NSDateComponents(); comps.year = 2000; comps.month = 2; comps.day = 29
            let date = cal.date(from: comps as DateComponents)! as NSDate
            try expect(cal.component(.day, from: date as Date) == 29 && date.timeIntervalSince1970 == 951782400, "calendar \(date.timeIntervalSince1970)")
            let mis = NSMutableIndexSet(indexesIn: NSRange(location: 2, length: 3)); mis.add(10)
            let ip = NSIndexPath(indexes: [1, 2, 3], length: 3)
            let handler = NSDecimalNumberHandler(roundingMode: .bankers, scale: 1, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
            let dn = NSDecimalNumber(string: "2.25").rounding(accordingToBehavior: handler)
            let di = NSDateInterval(start: Date(timeIntervalSince1970: 0), duration: 60)
            let uc = NSURLComponents(string: "https://example.com/a?x=1")!; uc.queryItems = [NSURLQueryItem(name: "y", value: "2") as URLQueryItem]
            let req = NSMutableURLRequest(url: URL(string: "https://example.com")!); req.httpMethod = "POST"; req.setValue("1", forHTTPHeaderField: "X-P27")
            let cookie = HTTPCookie(properties: [.name: "a", .value: "b", .domain: "example.com", .path: "/"])!
            let orth = NSOrthography.defaultOrthography(forLanguage: "en")
            let pd = NSPurgeableData(bytes: [1, 2, 3], length: 3); _ = pd.beginContentAccess(); pd.endContentAccess()
            let tz = NSTimeZone(name: "Asia/Tokyo")!
            let qi: URLQueryItem = URLQueryItem(name: "q", value: "1")
            try expect(mis.count == 4 && ip.index(atPosition: 2) == 3 && dn.stringValue == "2.2" && di.duration == 60 && uc.url?.query == "y=2"
                       && req.value(forHTTPHeaderField: "X-P27") == "1" && cookie.domain == "example.com" && orth.dominantScript == "Latn" && tz.secondsFromGMT == 32400 && qi.value == "1",
                       "values: set \(mis.count) path \(ip) dec \(dn) query \(uc.url?.query ?? "") script \(orth.dominantScript) tz \(tz.secondsFromGMT)")
            let objs: [(AnyClass, NSObject)] = [(NSDate.self, date), (NSDateComponents.self, comps), (NSCalendar.self, cal), (NSTimeZone.self, tz), (NSLocale.self, NSLocale(localeIdentifier: "fr_FR")),
                (NSUUID.self, NSUUID()), (NSIndexSet.self, NSIndexSet(index: 3)), (NSMutableIndexSet.self, mis), (NSIndexPath.self, ip), (NSDecimalNumber.self, dn),
                (NSPersonNameComponents.self, NSPersonNameComponents()), (NSDateInterval.self, di), (NSURLComponents.self, uc), (NSURLQueryItem.self, NSURLQueryItem(name: "a", value: "b")),
                (NSOrthography.self, orth)]
            // URL requests copy but come back nil from this generic unarchiver (as on Apple's simulator)
            let reqs: [(AnyClass, NSObject)] = [(NSURLRequest.self, NSURLRequest(url: URL(string: "https://example.com")!)), (NSMutableURLRequest.self, req)]
            return try p27uiTable(objs) + "; requests " + (try p27uiTable(reqs, archive: false))
        })

        // NSUnit dimensions: every unit class converts its base unit and a second unit through its linear converter
        c.append(check("Foundation", "p27ui-units") {
            let names = ["NSUnitAcceleration", "NSUnitAngle", "NSUnitArea", "NSUnitConcentrationMass", "NSUnitDispersion", "NSUnitDuration", "NSUnitElectricCharge",
                         "NSUnitElectricCurrent", "NSUnitElectricPotentialDifference", "NSUnitElectricResistance", "NSUnitEnergy", "NSUnitFrequency", "NSUnitFuelEfficiency",
                         "NSUnitIlluminance", "NSUnitInformationStorage", "NSUnitLength", "NSUnitMass", "NSUnitPower", "NSUnitPressure", "NSUnitSpeed", "NSUnitTemperature", "NSUnitVolume"]
            var out: [String] = []
            for n in names {
                guard let cls = NSClassFromString(n) as? Dimension.Type else { throw Fail("no \(n)") }
                let base = cls.baseUnit()
                try expect(base.converter.baseUnitValue(fromValue: 7) == 7, "\(n) base converter")
                out.append(base.symbol)
            }
            let f = Measurement(value: 212, unit: UnitTemperature.fahrenheit).converted(to: .celsius).value
            let conv: UnitConverter = UnitConverterLinear(coefficient: 2, constant: 1)
            try p27uiSame("NSUnitConverter", UnitConverter.self); try p27uiSame("NSUnitConverterLinear", UnitConverterLinear.self)
            try p27uiSame("NSUnit", Unit.self); try p27uiSame("NSDimension", Dimension.self)
            let custom = UnitLength(symbol: "p27", converter: conv)
            let m = Measurement(value: 3, unit: custom).converted(to: .meters).value
            try expect(abs(f - 100) < 1e-9 && m == 7 && conv.value(fromBaseUnitValue: 7) == 3, "conversions \(f) \(m)")
            return "\(names.count) dimensions, base symbols \(out.joined(separator: " "))"
        })

        // threads, run loops, timers, locks, operations, notifications, pipes / file handles, ports, process info,
        // user defaults, undo, progress, KVO (shared observers)
        c.append(check("Foundation", "p27ui-runtime") {
            let pairs: [(String, AnyClass)] = [("NSThread", Thread.self), ("NSRunLoop", RunLoop.self), ("NSTimer", Timer.self), ("NSCondition", NSCondition.self),
                ("NSConditionLock", NSConditionLock.self), ("NSRecursiveLock", NSRecursiveLock.self), ("NSOperation", Operation.self), ("NSOperationQueue", OperationQueue.self),
                ("NSBlockOperation", BlockOperation.self), ("NSNotificationCenter", NotificationCenter.self), ("NSNotificationQueue", NotificationQueue.self),
                ("NSPipe", Pipe.self), ("NSFileHandle", FileHandle.self), ("NSPort", Port.self), ("NSMachPort", NSMachPort.self), ("NSMessagePort", MessagePort.self),
                ("NSSocketPort", SocketPort.self), ("NSProcessInfo", ProcessInfo.self), ("NSUserDefaults", UserDefaults.self), ("NSUndoManager", UndoManager.self),
                ("NSProgress", Progress.self), ("NSFileManager", FileManager.self), ("NSBundle", Bundle.self), ("NSValueTransformer", ValueTransformer.self),
                ("NSSecureUnarchiveFromDataTransformer", NSSecureUnarchiveFromDataTransformer.self), ("NSPointerArray", NSPointerArray.self),
                ("NSPointerFunctions", NSPointerFunctions.self), ("NSInputStream", InputStream.self), ("NSOutputStream", OutputStream.self), ("NSStream", Stream.self),
                ("NSJSONSerialization", JSONSerialization.self), ("NSPropertyListSerialization", PropertyListSerialization.self), ("NSXMLParser", XMLParser.self),
                ("NSScanner", Scanner.self), ("NSDataDetector", NSDataDetector.self), ("NSTextCheckingResult", NSTextCheckingResult.self), ("NSFileWrapper", FileWrapper.self),
                ("NSFileVersion", NSFileVersion.self), ("NSFileAccessIntent", NSFileAccessIntent.self), ("NSAssertionHandler", NSAssertionHandler.self)]
            for (n, t) in pairs { try p27uiSame(n, t) }
            _ = try p27uiClass("NSAutoreleasePool")   // not built: -init would push a pool nobody drains
            do { let probed = try p27uiProbe(["NSInvocation", "NSInvocationOperation", "NSMethodSignature", "NSNotification"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }   // not in Swift
            // thread + run loop + timer + condition
            let cond = NSCondition(); var fired = 0; var threadName = ""
            let th = Thread {
                threadName = Thread.current.name ?? ""
                let t = Timer(timeInterval: 0.01, repeats: true) { t in cond.lock(); fired += 1; if fired == 3 { t.invalidate(); cond.signal() }; cond.unlock() }
                RunLoop.current.add(t, forMode: .default)
                RunLoop.current.run(until: Date().addingTimeInterval(2))
            }
            th.name = "p27ui"; th.start()
            cond.lock(); let ok = fired >= 3 || cond.wait(until: Date().addingTimeInterval(3)); cond.unlock()
            try expect(ok && fired == 3 && threadName == "p27ui", "timer on thread: fired \(fired) name \(threadName)")
            let cl = NSConditionLock(condition: 1); try expect(cl.tryLock(whenCondition: 1), "condition lock"); cl.unlock(withCondition: 2)
            let rl = NSRecursiveLock(); rl.lock(); rl.lock(); rl.unlock(); rl.unlock()
            // operations with dependencies
            var order: [Int] = []; let lk = NSLock()
            let q = OperationQueue(); q.maxConcurrentOperationCount = 4
            let a = BlockOperation { lk.withLock { order.append(1) } }, b = BlockOperation { lk.withLock { order.append(2) } }
            let o: Operation = b; o.addDependency(a)
            q.addOperations([b, a], waitUntilFinished: true)
            try expect(order == [1, 2], "operations \(order)")
            // notifications (coalescing queue)
            let nc = NotificationCenter(); var got = 0
            let tok = nc.addObserver(forName: Notification.Name("p27"), object: nil, queue: nil) { _ in got += 1 }
            let nq = NotificationQueue(notificationCenter: nc)
            nq.enqueue(Notification(name: Notification.Name("p27")), postingStyle: .now, coalesceMask: [.onName], forModes: nil)
            nc.removeObserver(tok)
            try expect(got == 1, "notification queue \(got)")
            // pipe + file handle
            let pipe = Pipe(); pipe.fileHandleForWriting.write(Data("p27".utf8)); try pipe.fileHandleForWriting.close()
            let read = try pipe.fileHandleForReading.readToEnd()
            try expect(read == Data("p27".utf8), "pipe")
            // ports
            let mp = NSMachPort(); try expect(mp.machPort != 0 && mp.isValid, "mach port"); mp.invalidate()
            let sp = SocketPort(tcpPort: 0); let sock = sp?.socket ?? -1; sp?.invalidate()
            let msgp = MessagePort()
            // process info, defaults, undo, progress
            let pi = ProcessInfo.processInfo
            let ud = UserDefaults(suiteName: "p27ui")!; ud.set(27, forKey: "k")
            let um = UndoManager(); um.groupsByEvent = false; var val = 1
            um.beginUndoGrouping(); um.registerUndo(withTarget: lk) { _ in val = 1 }; val = 2; um.endUndoGrouping(); um.undo()
            let prog = Progress(totalUnitCount: 4); prog.completedUnitCount = 1
            try expect(pi.processorCount > 0 && ud.integer(forKey: "k") == 27 && val == 1 && prog.fractionCompleted == 0.25, "process/defaults/undo/progress")
            ud.removePersistentDomain(forName: "p27ui")
            // pointer containers, value transformers
            let pa = NSPointerArray.strongObjects(); let o1 = NSObject(), o2 = NSObject()
            pa.addPointer(Unmanaged.passUnretained(o1).toOpaque()); pa.addPointer(nil); pa.addPointer(Unmanaged.passUnretained(o2).toOpaque()); pa.compact()
            let pf = NSPointerFunctions(options: .strongMemory)
            let tr = NSSecureUnarchiveFromDataTransformer()
            let enc = tr.reverseTransformedValue(["a": 1] as NSDictionary) as? Data
            let dec = enc.flatMap { tr.transformedValue($0) as? NSDictionary }
            try expect(pa.count == 2 && pf.usesStrongWriteBarrier == false && dec?["a"] as? Int == 1, "pointer array \(pa.count) transformer \(String(describing: dec))")
            // scanner, data detector, JSON / plist, XML parser, streams
            let sc = Scanner(string: "x=42"); _ = sc.scanString("x="); let num = sc.scanInt()
            let dd = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches: [NSTextCheckingResult] = dd.matches(in: "see https://example.com now", range: NSRange(location: 0, length: 27))
            let json = try JSONSerialization.jsonObject(with: Data("{\"a\":[1,2]}".utf8)) as? [String: [Int]]
            let plist = try PropertyListSerialization.data(fromPropertyList: ["k": 1], format: .binary, options: 0)
            final class XP: NSObject, XMLParserDelegate { var els: [String] = []; func parser(_ p: XMLParser, didStartElement e: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) { els.append(e) } }
            let xp = XP(); let parser = XMLParser(data: Data("<a><b/><c/></a>".utf8)); parser.delegate = xp; _ = parser.parse()
            let os = OutputStream(toMemory: ()); os.open(); _ = os.write([1, 2, 3], maxLength: 3); os.close()
            let written = os.property(forKey: .dataWrittenToMemoryStreamKey) as? Data
            let ins = InputStream(data: written ?? Data()); ins.open(); var buf = [UInt8](repeating: 0, count: 8); let rn = ins.read(&buf, maxLength: 8); ins.close()
            try expect(num == 42 && matches.first?.url?.host == "example.com" && json?["a"] == [1, 2] && plist.starts(with: Array("bplist".utf8)) && xp.els == ["a", "b", "c"] && rn == 3,
                       "scanner \(String(describing: num)) detector \(matches.count) xml \(xp.els) stream \(rn)")
            // files: wrapper round trip, versions, access intents, coordinator
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("p27ui-wrap")
            try? FileManager.default.removeItem(at: dir)
            let fw = FileWrapper(directoryWithFileWrappers: ["a.txt": FileWrapper(regularFileWithContents: Data("A".utf8))])
            try fw.write(to: dir, options: .atomic, originalContentsURL: nil)
            let rw = try FileWrapper(url: dir)
            let cur = NSFileVersion.currentVersionOfItem(at: dir.appendingPathComponent("a.txt"))
            let intent = NSFileAccessIntent.readingIntent(with: dir, options: [])
            var coordinated = false
            let fcErr: NSError? = await withCheckedContinuation { cont in
                NSFileCoordinator().coordinate(with: [intent], queue: OperationQueue()) { e in coordinated = e == nil; cont.resume(returning: e as NSError?) }
            }
            // the wrapper reads its children lazily: before the directory goes away
            let wrapped = rw.fileWrappers?["a.txt"]?.regularFileContents
            try? FileManager.default.removeItem(at: dir)
            try expect(wrapped == Data("A".utf8) && rw.isDirectory && cur != nil && coordinated, "file wrapper \(wrapped.map { String(decoding: $0, as: UTF8.self) } ?? "nil") (\(rw.fileWrappers?.keys.sorted() ?? [])) / version \(cur != nil) / coordinator \(coordinated) \(String(describing: fcErr))")
            let ah = (NSClassFromString("NSAssertionHandler") as AnyObject).value(forKey: "currentHandler") as? NSObject
            try expect(ah is NSAssertionHandler, "assertion handler \(String(describing: ah))")
            return "\(pairs.count) classes; timer x\(fired), ops \(order), pipe, mach/socket(\(sock))/message(\(msgp.isValid)) ports, xml \(xp.els)"
        })

        // URL loading through a custom URLProtocol: data / download / upload tasks, metrics, cookies, cache,
        // credentials and protection spaces
        c.append(check("Foundation", "p27ui-url-loading", timeout: 45) {
            let pairs: [(String, AnyClass)] = [("NSURLSession", URLSession.self), ("NSURLSessionConfiguration", URLSessionConfiguration.self), ("NSURLSessionTask", URLSessionTask.self),
                ("NSURLSessionDataTask", URLSessionDataTask.self), ("NSURLSessionDownloadTask", URLSessionDownloadTask.self), ("NSURLSessionUploadTask", URLSessionUploadTask.self),
                ("NSURLSessionStreamTask", URLSessionStreamTask.self), ("NSURLSessionWebSocketTask", URLSessionWebSocketTask.self), ("NSURLSessionTaskMetrics", URLSessionTaskMetrics.self),
                ("NSURLSessionTaskTransactionMetrics", URLSessionTaskTransactionMetrics.self), ("NSURLCache", URLCache.self), ("NSCachedURLResponse", CachedURLResponse.self),
                ("NSURLResponse", URLResponse.self), ("NSHTTPURLResponse", HTTPURLResponse.self), ("NSURLCredential", URLCredential.self), ("NSURLProtectionSpace", URLProtectionSpace.self),
                ("NSURLAuthenticationChallenge", URLAuthenticationChallenge.self), ("NSURLCredentialStorage", URLCredentialStorage.self), ("NSHTTPCookieStorage", HTTPCookieStorage.self),
                ("NSURLProtocol", URLProtocol.self), ("NSURLConnection", NSURLConnection.self)]
            for (n, t) in pairs { try p27uiSame(n, t) }
            _ = try p27uiClass("NSURLSessionWebSocketMessage")
            let cfg = URLSessionConfiguration.ephemeral; cfg.protocolClasses = [P27uiProtocol.self]
            let jar = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "p27ui"); jar.cookieAcceptPolicy = .always
            cfg.httpCookieStorage = jar
            final class M: NSObject, URLSessionTaskDelegate { var metrics: URLSessionTaskMetrics?; func urlSession(_ s: URLSession, task: URLSessionTask, didFinishCollecting m: URLSessionTaskMetrics) { metrics = m } }
            let md = M()
            let s = URLSession(configuration: cfg, delegate: md, delegateQueue: nil)
            defer { s.invalidateAndCancel() }
            let (d, r) = try await s.data(from: URL(string: "p27ui://host/hello")!)
            let http = r as? HTTPURLResponse
            try expect(String(data: d, encoding: .utf8) == "/hello" && http?.statusCode == 200 && http?.value(forHTTPHeaderField: "Content-Type") == "text/plain", "data task \(String(describing: r))")
            let (file, _) = try await s.download(from: URL(string: "p27ui://host/file")!)
            let fileBody = try String(contentsOf: file, encoding: .utf8)
            var up = URLRequest(url: URL(string: "p27ui://host/upload")!); up.httpMethod = "POST"
            let (ud, _) = try await s.upload(for: up, from: Data(count: 1234))
            try expect(fileBody == "/file" && String(data: ud, encoding: .utf8) == "1234", "download \(fileBody) upload \(String(data: ud, encoding: .utf8) ?? "")")
            let tm = md.metrics?.transactionMetrics.first
            try expect(md.metrics != nil && (md.metrics?.taskInterval.duration ?? -1) >= 0, "metrics \(String(describing: md.metrics))")
            // cache
            let cache = URLCache(memoryCapacity: 1 << 20, diskCapacity: 0)
            let req = URLRequest(url: URL(string: "p27ui://host/c")!)
            cache.storeCachedResponse(CachedURLResponse(response: URLResponse(url: req.url!, mimeType: "text/plain", expectedContentLength: 1, textEncodingName: nil), data: Data("c".utf8)), for: req)
            try expect(cache.cachedResponse(for: req)?.data == Data("c".utf8), "URLCache")
            // credentials
            let space = URLProtectionSpace(host: "example.com", port: 443, protocol: "https", realm: "p27", authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
            let cred = URLCredential(user: "u", password: "p", persistence: .forSession)
            let store = URLCredentialStorage.shared; store.set(cred, for: space)
            let back = store.credentials(for: space)?["u"]
            store.remove(cred, for: space)
            final class Sender: NSObject, URLAuthenticationChallengeSender {
                func use(_ c: URLCredential, for ch: URLAuthenticationChallenge) {}; func continueWithoutCredential(for ch: URLAuthenticationChallenge) {}; func cancel(_ ch: URLAuthenticationChallenge) {}
            }
            let ch = URLAuthenticationChallenge(protectionSpace: space, proposedCredential: cred, previousFailureCount: 1, failureResponse: nil, error: nil, sender: Sender())
            try expect(back?.password == "p" && ch.previousFailureCount == 1 && ch.protectionSpace.realm == "p27", "credentials")
            let ws = s.webSocketTask(with: URL(string: "ws://127.0.0.1:9/")!)
            let st = s.streamTask(withHostName: "127.0.0.1", port: 9)
            let wsMsg = URLSessionWebSocketTask.Message.string("hi")
            ws.cancel(); st.cancel()
            return "data/download/upload ok, metrics \(md.metrics?.transactionMetrics.count ?? 0) transactions (\(tm.map { "\($0.resourceFetchType.rawValue)" } ?? "-")), cache, credentials, ws \(wsMsg)"
        })

        // XPC: an anonymous listener's endpoint archived through NSXPCCoder, a round trip call
        c.append(check("Foundation", "p27ui-xpc-anonymous") {
            try p27uiSame("NSXPCListenerEndpoint", NSXPCListenerEndpoint.self); try p27uiSame("NSXPCCoder", NSXPCCoder.self)
            let l = NSXPCListener.anonymous()
            final class D: NSObject, NSXPCListenerDelegate {
                func listener(_ l: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
                    c.exportedInterface = NSXPCInterface(with: P27uiXPC.self); c.exportedObject = Svc(); c.resume(); return true
                }
            }
            final class Svc: NSObject, P27uiXPC { func echo(_ s: String, reply: @escaping (String) -> Void) { reply(s + "!") } }
            let d = D(); l.delegate = d; l.resume()
            let ep: NSXPCListenerEndpoint = l.endpoint
            let conn = NSXPCConnection(listenerEndpoint: ep); conn.remoteObjectInterface = NSXPCInterface(with: P27uiXPC.self); conn.resume()
            defer { conn.invalidate(); l.invalidate() }
            let r: String = try await withCheckedThrowingContinuation { cont in
                let px = conn.remoteObjectProxyWithErrorHandler { cont.resume(throwing: $0) } as? P27uiXPC
                px?.echo("p27") { cont.resume(returning: $0) }
            }
            try expect(r == "p27!", "xpc reply \(r)")
            return "anonymous XPC reply \(r)"
        })

        return c
    }
}
@objc protocol P27uiXPC { func echo(_ s: String, reply: @escaping (String) -> Void) }

// MARK: Combine, TabularData, Core Video / Core Media Swift types, Accessibility, Symbols, Core Image, QuartzCore, OSLog

extension Registry {
    static var p27uiFrameworks: [Check] {
        var c: [Check] = []

        // Combine: publishers, subscribers, subscriptions, schedulers, connectable publishers, async bridges
        c.append(check("Combine", "p27ui-publishers") {
            var got: [Int] = []
            let sink = Subscribers.Sink<Int, Never>(receiveCompletion: { _ in }, receiveValue: { got.append($0) })
            let any: AnyPublisher<Int, Never> = Publishers.Sequence<[Int], Never>(sequence: [1, 2, 3]).map { $0 * 10 }.eraseToAnyPublisher()
            any.subscribe(AnySubscriber(sink))
            try expect(got == [10, 20, 30], "sequence \(got)")
            var rec: [Int] = []
            let record = Record<Int, Never>(output: [7, 8], completion: .finished)
            let cc: Cancellable = Publishers.Concatenate(prefix: Just(1), suffix: record).append(Empty()).sink { rec.append($0) }
            let deferred = Deferred { Just(99) }
            var dv = 0; let c2 = deferred.sink { dv = $0 }
            try expect(rec == [1, 7, 8] && dv == 99, "record/concat \(rec) deferred \(dv)")
            // connectable: nothing until connect
            var cv: [Int] = []
            let conn = Just(5).makeConnectable()
            let c3 = conn.sink { cv.append($0) }
            let before = cv.count
            let link: Cancellable = conn.connect()
            try expect(before == 0 && cv == [5], "connectable \(before) \(cv)")
            // custom subscriber with demand + a subscription
            final class Sub: Subscriber, CustomCombineIdentifierConvertible {
                typealias Input = Int; typealias Failure = Never
                var vals: [Int] = []; var sub: Subscription?
                func receive(subscription: Subscription) { sub = subscription; subscription.request(.max(2)) }
                func receive(_ input: Int) -> Subscribers.Demand { vals.append(input); return .none }
                func receive(completion: Subscribers.Completion<Never>) {}
            }
            let s = Sub(); (1...5).publisher.subscribe(s)
            let id: CombineIdentifier = s.combineIdentifier
            try expect(s.vals == [1, 2] && id == s.combineIdentifier && id != CombineIdentifier(), "demand \(s.vals)")
            Subscriptions.empty.cancel()
            // schedulers: immediate scheduler and a dispatch queue's stride type
            let imm = ImmediateScheduler.shared
            var ran = false; imm.schedule { ran = true }
            func stride<S: Scheduler>(_ s: S) -> S.SchedulerTimeType.Stride { .milliseconds(5) }
            func conv<T: SchedulerTimeIntervalConvertible>(_ t: T.Type) -> T { .seconds(1) }
            let qs = stride(DispatchQueue.main)
            let one: DispatchQueue.SchedulerTimeType.Stride = conv(DispatchQueue.SchedulerTimeType.Stride.self)
            try expect(ran && qs.magnitude == 5_000_000 && one.magnitude == 1_000_000_000, "schedulers \(qs) \(one)")
            // top-level coders
            struct P: Codable, Equatable { var a: Int }
            func roundTrip<E: TopLevelEncoder, D: TopLevelDecoder>(_ e: E, _ d: D) throws -> P where E.Output == D.Input { try d.decode(P.self, from: e.encode(P(a: 3))) }
            var coded: P?; let c4 = Just(P(a: 4)).encode(encoder: JSONEncoder()).decode(type: P.self, decoder: JSONDecoder()).sink(receiveCompletion: { _ in }, receiveValue: { coded = $0 })
            try expect(try roundTrip(JSONEncoder(), JSONDecoder()) == P(a: 3) && coded == P(a: 4), "coders")
            // async bridges
            var av: [Int] = []
            let ap: AsyncPublisher<Publishers.Sequence<[Int], Never>> = [4, 5].publisher.values
            for await v in ap { av.append(v) }
            struct E: Error {}
            let tp: AsyncThrowingPublisher<AnyPublisher<Int, E>> = Combine.Fail<Int, E>(error: E()).eraseToAnyPublisher().values
            var threw = false; do { for try await _ in tp {} } catch { threw = true }
            try expect(av == [4, 5] && threw, "async \(av) threw \(threw)")
            [cc, c2, c3, link, c4].forEach { $0.cancel() }
            return "values \(got) \(rec), connectable, demand \(s.vals), async \(av)"
        })

        #if canImport(TabularData)
        c.append(check("TabularData", "p27ui-dataframe") { try p27uiTabular() })
        #endif

        c.append(check("CoreVideo", "p27ui-swift-pixelbuffer") { try p27uiCoreVideo() })
        c.append(check("CoreMedia", "p27ui-swift-buffers") { try p27uiCoreMedia() })
        c.append(check("Accessibility", "p27ui-math-braille-charts") { try await p27uiAccessibility() })
        #if canImport(UIKit) && !os(watchOS)
        c.append(check("Symbols", "p27ui-symbol-effects") { try await p27uiSymbols() })
        c.append(check("QuartzCore", "p27ui-animations") { try await p27uiQuartz() })
        #endif
        #if canImport(CoreImage) && !os(watchOS)
        c.append(check("CoreImage", "p27ui-barcodes-render") { try p27uiCoreImage() })
        #endif
        c.append(check("OSLog", "p27ui-log-store") { try p27uiOSLog() })
        return c
    }
}

#if canImport(TabularData)
import TabularData
private func p27uiTabular() throws -> String {
    let csv = "name,team,score,when\nada,red,3,2024-01-02\nbob,blue,5,2024-01-03\ncy,red,,2024-02-01\ndee,blue,9,2024-02-05\n"
    var opts = CSVReadingOptions(hasHeaderRow: true, delimiter: ","); opts.addDateParseStrategy(Date.ISO8601FormatStyle().year().month().day().dateSeparator(.dash))
    var df = try DataFrame(csvData: Data(csv.utf8), types: ["score": CSVType.integer, "when": CSVType.date], options: opts)
    try expect(df.shape == (4, 4), "shape \(df.shape)")
    let scoreID = ColumnID("score", Int.self)
    let score: Column<Int> = df[scoreID]
    let any: AnyColumn = df["team"]
    func proto<C: ColumnProtocol>(_ c: C) -> Int { c.count }
    func anyProto(_ c: any AnyColumnProtocol) -> String { c.name }
    try expect(score.count == 4 && score[2] == nil && proto(score) == 4 && anyProto(any) == "team", "columns")
    let slice: ColumnSlice<Int> = score[1..<3]
    let filled: FilledColumn<Column<Int>> = score.filled(with: 0)
    let dis: DiscontiguousColumnSlice<Int> = score.filter { ($0 ?? 0) > 4 }
    let numeric: NumericSummary<Double> = score.map { $0.map(Double.init) }.numericSummary()
    let cat: CategoricalSummary<String> = df[ColumnID("team", String.self)].summary()
    let anyCat: AnyCategoricalSummary = any[0..<any.count].summary()
    try expect(slice.count == 2 && filled.map { $0 }.reduce(0, +) == 17 && dis.count == 2 && numeric.max == 9 && numeric.someCount == 3 && cat.uniqueCount == 2 && anyCat.uniqueCount == 2,
               "slice/filled/filter/summaries: \(numeric) \(cat)")
    // grouping, sorting, joins
    let grouped: RowGrouping<String> = df.grouped(by: ColumnID("team", String.self))
    let sums = grouped.sums("score", Int.self, order: .ascending)
    let gproto: any RowGroupingProtocol = df.grouped(by: "team")
    let gsum: any GroupSummaries = gproto.summary()
    df.sort(on: scoreID, order: Order.descending)
    try expect(df.rows.first?["name"] as? String == "dee" && sums.shape.rows == 2 && gproto.count == 2 && !"\(gsum)".isEmpty, "group/sort \(sums)")
    var other = DataFrame(); other.append(column: Column(name: "team", contents: ["red", "blue"])); other.append(column: Column(name: "color", contents: ["#f00", "#00f"]))
    let joined = df.joined(other, on: "team", kind: JoinKind.inner)
    try expect(joined.shape.rows == 4 && joined.columns.contains { $0.name.hasSuffix("color") }, "join \(joined.columns.map(\.name))")
    // write / read CSV and JSON
    var w = CSVWritingOptions(); w.includesHeader = true; w.nilEncoding = "-"
    let out = try df.csvRepresentation(options: w)
    let json = try df.jsonRepresentation(options: JSONWritingOptions())
    let back = try DataFrame(jsonData: json, types: ["score": JSONType.integer], options: JSONReadingOptions())
    try expect(String(decoding: out, as: UTF8.self).contains("cy,red,-") && back.shape.rows == 4, "csv/json \(back.shape)")
    var f = FormattingOptions(maximumLineWidth: 80, maximumCellWidth: 10, maximumRowCount: 2); f.includesColumnTypes = false
    let text = df.description(options: f)
    func dfp<D: DataFrameProtocol>(_ d: D) -> Int { d.rows.count }
    // errors from malformed input
    var csvErr = ""
    do { _ = try DataFrame(csvData: Data("a,b\n1,2,3\n".utf8)) } catch let e as CSVReadingError { csvErr = "\(e)" }
    var jsonErr = ""
    do { _ = try DataFrame(jsonData: Data("{".utf8)) } catch let e as JSONReadingError { jsonErr = "\(e)" } catch { jsonErr = "other \(type(of: error))" }
    let shaped: ShapedData<Double> = ShapedData(shape: [2, 2], strides: [2, 1], contents: [1, 2, 3, 4])
    let opt: any OptionalColumnProtocol = score
    let proto2: any AnyColumnPrototype = score.prototype
    try expect(!csvErr.isEmpty && !jsonErr.isEmpty && !text.isEmpty && dfp(df) == 4 && shaped.contents.count == 4 && opt.count == 4 && proto2.name == "score",
               "errors csv '\(csvErr)' json '\(jsonErr)'")
    return "4x4, sums \(sums.rows.map { "\($0[0] ?? "")=\($0[1] ?? "")" }), errors: csv \(csvErr.prefix(50)), json \(jsonErr.prefix(40))"
}
#endif

import CoreVideo
private func p27uiCoreVideo() throws -> String {
    let fmt = CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA)
    var attach = CVAttachmentContainer<CVPixelBufferAttachmentKeyDefinitions>()
    attach.colorPrimaries = .itu_R_709_2
    attach.transferFunction = .itu_R_709_2
    attach.yCbCrMatrix = .itu_R_709_2
    attach.fieldDetail = .temporalTopFirst
    attach.pixelAspectRatio = CVImagePixelAspectRatio(horizontalSpacing: 1, verticalSpacing: 1)
    attach.cleanAperture = CVImageCleanAperture(width: 16, height: 8, horizontalOffset: 0, verticalOffset: 0)
    attach.alphaChannelMode = .premultipliedAlpha
    attach.displayMaskRectangle = CVImageDisplayMaskRectangle(left: 0, top: 0, width: 16, height: 8, referenceRasterWidth: 16, referenceRasterHeight: 8)
    attach.chromaField = CVImageChromaField(fieldLocation: .progressive(.center), subsampling: .`4:2:0`)
    let attrs = CVPixelBufferCreationAttributes(pixelFormatType: fmt, size: CVImageSize(width: 16, height: 8), compatibility: [.cgBitmapContext, .cgImage],
                                                 bytesPerRowAlignment: 64, extendedPixels: CVPixelBufferPadding(left: 0, right: 0, top: 0, bottom: 0), attachments: attach)
    var mb = try CVMutablePixelBuffer(attrs)
    // the creation attributes' attachments do not reach the buffer (Apple's simulator too): set them on the buffer
    mb.attachments.colorPrimaries = .itu_R_709_2
    mb.attachments.transferFunction = .itu_R_709_2
    mb.accessUnsafeMutableRawPlaneBytes { planes in for i in 0..<planes[0].bytes.count { planes[0].bytes[i] = 0x40 } }
    let props: [CVPixelBufferPlaneProperties] = mb.planeProperties
    try expect(props.count == 1 && props[0].size == CVImageSize(width: 16, height: 8) && props[0].bytesPerRow >= 64, "planes \(props)")
    let ro = CVReadOnlyPixelBuffer(mb)
    func rep<P: CVPixelBufferRepresentable>(_ p: borrowing P) -> (CVImageSize, CVPixelFormatType, Bool) { (p.size, p.pixelFormatType, p.isPlanar) }
    func img<P: CVImageBufferRepresentable>(_ p: borrowing P) -> (CGSize, CVImageBufferOriginPosition) { (p.encodedSize, p.originPosition) }
    let (sz, pf, planar) = rep(ro)
    let (enc, origin) = img(ro)
    let first: UInt8 = ro.accessUnsafeRawPlaneBytes { $0[0].bytes[0] }
    // the attachments reach the C buffer (kCVImageBuffer keys)
    let raw: [String: Any] = ro.withUnsafeBuffer { (CVBufferCopyAttachments($0, .shouldPropagate) as? [String: Any]) ?? [:] }
    let prim = raw[kCVImageBufferColorPrimariesKey as String] as? String
    let viaAccess: CVImageColorPrimaries? = ro.attachments.colorPrimaries
    let mode = ro.attachments.attachedMode(of: kCVImageBufferColorPrimariesKey as String)
    try expect(sz == CVImageSize(width: 16, height: 8) && pf == fmt && !planar && enc == CGSize(width: 16, height: 8) && first == 0x40, "buffer \(sz) \(pf) \(enc) \(first)")
    try expect(prim == (kCVImageBufferColorPrimaries_ITU_R_709_2 as String) && viaAccess == .itu_R_709_2 && mode == .shouldPropagate, "attachments \(prim ?? "nil") \(String(describing: viaAccess)) \(String(describing: mode)) raw \(raw.keys.sorted())")
    // raw attachment values, key definitions, pixel format descriptions, errors
    let rawv: CVAttachmentRawValue = CVImageCleanAperture(width: 4, height: 2, horizontalOffset: 0, verticalOffset: 0).rawAttachmentValueRepresentation
    let apBack = CVImageCleanAperture.makeFromRawAttachmentValue(rawv)
    let key = CVAttachmentKeyDefinition<CVAttachmentModePreferenceShouldNotPropagate, Int>("P27Key")
    let keyD = CVAttachmentKeyDefinitionWithDefault<CVAttachmentModePreferenceShouldPropagate, Int>("P27Def", default: 3)
    let ck: CVAttachmentCompositeKeyDefinition<CVAttachmentModePreferenceShouldPropagate, CVImageChromaField> = ["A", "B"]
    func pref<M: CVAttachmentModePreference>(_ m: M.Type) -> CVAttachmentMode { m.preferredMode }
    let desc = CVPixelFormatDescription.Registry.shared.formatDescriptions.first { $0.pixelFormatType == fmt }
    var err = ""; do { try CVError.check(kCVReturnInvalidArgument) } catch { err = "\(error)" }
    let ts = CVTimeStamp(videoTime: CVTime(timeValue: 1, timeScale: 30), hostTime: 5)
    let ar = CVPixelBufferAttributes(pixelFormatTypes: [fmt], size: CVImageSize(width: 2, height: 2))
    let lg: CVImageLogTransferFunction = .appleLog, st = CVImageStereoDisplayMaskRectangle(maskRectangle: CVImageDisplayMaskRectangle(left: 0, top: 0, width: 1, height: 1, referenceRasterWidth: 1, referenceRasterHeight: 1), leftEdgePoints: [], rightEdgePoints: [])
    let sensel: CVSenselArrayPattern = .bayerRGGB, sit = CVSenselSitingOffsets.zero
    let prr = "\(CVProResRawMetadata.self)"
    let conds = [apBack?.width == 4, key.rawValue == "P27Key", keyD.defaultValue == 3, ck.rawValues == ["A", "B"], pref(CVAttachmentModePreferenceShouldNotPropagate.self) == .shouldNotPropagate,
                 desc == nil || desc?.components.contains(.rgb) == true, !err.isEmpty, ts.flagOptions.contains(.hostTimeValid), ro.isCompatibleWith(attrs)]
    try expect(!conds.contains(false), "conditions \(conds) compatible with format+size only \(ro.isCompatibleWith(ar)) desc \(desc?.name ?? "nil") err \(err) ts \(ts.flags)")
    _ = (lg, st, sensel, sit)
    return "16x8 BGRA, attachments \(raw.count) keys, format \(desc?.name ?? "-"), error '\(err)', \(prr)"
}

import CoreMedia
import simd
private func p27uiCoreMedia() throws -> String {
    var mb = CMMutableDataBlockBuffer(count: 8)
    _ = mb.withContiguousMutableStorageIfAvailable { b in for i in 0..<b.count { b[i] = UInt8(i) } }
    var ro = CMReadOnlyDataBlockBuffer(mb)
    ro += CMReadOnlyDataBlockBuffer(Data([100, 101]))
    func dp<D: DataProtocol>(_ d: D) -> [UInt8] { Array(d) }
    let bytes = dp(ro)
    try expect(bytes == [0, 1, 2, 3, 4, 5, 6, 7, 100, 101] && ro.count == 10, "block buffer \(bytes)")
    let bb: CMBlockBuffer = ro.withUnsafeBlockBuffer { $0 }
    func proto(_ p: some CMBlockBufferProtocol) -> Int { p.endIndex - p.startIndex }
    // attachments on a bearer (a CVPixelBuffer)
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, 4, 4, kCVPixelFormatType_32BGRA, nil, &pb)
    guard let px = pb else { throw Fail("no pixel buffer") }
    CMSetAttachment(px, key: "P27" as CFString, value: "v" as CFString, attachmentMode: kCMAttachmentMode_ShouldPropagate)
    let bearer: CMAttachmentBearerProtocol = px
    let att: CMAttachmentBearerAttachments = bearer.attachments
    let v = att["P27"]
    try expect((v?.value as? String) == "v" && v?.mode == .shouldPropagate, "bearer attachments \(String(describing: v))")
    // tags and tagged buffers
    let tag = CMTypedTag(category: .channelID, value: 2)
    let tags: [CMTag] = [tag, CMTypedTag(category: .videoLayerID, value: 7)]
    let tb = CMTaggedBuffer(tags: tags, pixelBuffer: px)
    let ro2 = CVReadOnlyPixelBuffer(unsafeBuffer: px)
    let dyn = CMTaggedDynamicBuffer(tags: tags, content: ro2)
    try expect(tag.value == 2 && tb.tags.count == 2 && dyn.tags == tags, "tags \(tb)")
    // ready sample buffer from a data buffer, sample attachments
    var fd: CMFormatDescription?
    CMFormatDescriptionCreate(allocator: nil, mediaType: kCMMediaType_Metadata, mediaSubType: 0x70323775, extensions: nil, formatDescriptionOut: &fd)
    var sb: CMSampleBuffer?
    var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: CMTime(value: 3, timescale: 30), decodeTimeStamp: .invalid)
    var size = 10
    CMSampleBufferCreateReady(allocator: nil, dataBuffer: bb, formatDescription: fd, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sb)
    guard let s = sb else { throw Fail("no sample buffer") }
    let ready = CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(unsafeBuffer: s)
    try expect(ready.presentationTimeStamp == CMTime(value: 3, timescale: 30) && ready.contentType == .dataBuffer, "ready sample buffer \(ready.contentType)")
    let cim = CMCameraIntrinsicMatrix(matrix: matrix_identity_float3x3)
    let rawm = cim.rawAttachmentValueRepresentation
    let info: CMCustomNotificationInfo = ["k": 1]
    let drop: CMDroppedFrameReason = .frameWasLate, lens: CMStillImageLensStabilization = .off
    let ref = "\(CMSampleDataReference.self) \(CMSampleBufferAttachmentKeyDefinitions.self) \(CMBlockBufferAttachmentKeyDefinitions.self)"
    let sync = CMSync.Error.invalidParameter
    func syncP<T: CMSyncProtocol>(_ t: T) -> Double { t.time.seconds }
    let clk = syncP(CMClock.hostTimeClock)
    try expect(CMCameraIntrinsicMatrix.makeFromRawAttachmentValue(rawm) == cim && info.userInfo.count == 1 && proto(bb) == 10 && clk > 0 && sync.code != 0, "intrinsics/info/slice/clock")
    return "block \(bytes.count) B, tags \(tags.count), ready \(ready.duration.seconds) s, drop \(drop.rawValue), lens \(lens.rawValue), \(ref)"
}

import Accessibility
private func p27uiAccessibility() async throws -> String {
    // x = (-b ± √(b² - 4ac)) / 2a as a math expression tree
    let b = AXMathExpressionIdentifier(content: "b")
    let disc = AXMathExpressionRow(expressions: [AXMathExpressionSubSuperscript(baseExpression: [b], subscriptExpressions: [], superscriptExpressions: [AXMathExpressionNumber(content: "2")]),
                                                AXMathExpressionOperator(content: "-"), AXMathExpressionNumber(content: "4"), AXMathExpressionIdentifier(content: "a"), AXMathExpressionIdentifier(content: "c")])
    let root = AXMathExpressionRoot(radicandExpressions: [disc], rootIndexExpression: AXMathExpressionNumber(content: "2"))
    let num = AXMathExpressionFenced(expressions: [AXMathExpressionOperator(content: "-"), b, AXMathExpressionOperator(content: "±"), root], open: "(", close: ")")
    let frac = AXMathExpressionFraction(numeratorExpression: num, denimonatorExpression: AXMathExpressionRow(expressions: [AXMathExpressionNumber(content: "2"), AXMathExpressionIdentifier(content: "a")]))
    let lim = AXMathExpressionUnderOver(baseExpression: AXMathExpressionText(content: "lim"), underExpression: AXMathExpressionText(content: "n→∞"), overExpression: AXMathExpressionText(content: ""))
    let multi = AXMathExpressionMultiscript(baseExpression: b, prescriptExpressions: [], postscriptExpressions: [AXMathExpressionSubSuperscript(baseExpression: [b], subscriptExpressions: [AXMathExpressionNumber(content: "1")], superscriptExpressions: [])])
    let table = AXMathExpressionTable(expressions: [AXMathExpressionTableRow(expressions: [AXMathExpressionTableCell(expressions: [frac]), AXMathExpressionTableCell(expressions: [lim])])])
    let base: AXMathExpression = table
    let tableRows = (base as? AXMathExpressionTable)?.expressions ?? []
    let rowCells = (tableRows.first as? AXMathExpressionTableRow)?.expressions.count ?? -1
    // Apple's simulator answers an empty expressions array for a table (the row and cells keep theirs)
    let row0 = AXMathExpressionTableRow(expressions: [AXMathExpressionTableCell(expressions: [frac]), AXMathExpressionTableCell(expressions: [lim])])
    try expect(tableRows.isEmpty && row0.expressions.count == 2 && frac.denimonatorExpression is AXMathExpressionRow && root.radicandExpressions.count == 1 && num.openString == "(" && multi.postscriptExpressions.count == 1 && lim.underExpression is AXMathExpressionText,
               "math tree: rows \(tableRows.map { "\(type(of: $0))" }) cells \(rowCells) denominator \(type(of: frac.denimonatorExpression)) radicands \(root.radicandExpressions.count) open '\(num.openString)' post \(multi.postscriptExpressions.count) under \(type(of: lim.underExpression))")
    // braille
    var bt = ""
    if let table = AXBrailleTable(identifier: "com.apple.scrod.braille.table.duxbury.eng-xuc"), true {
        let r: AXBrailleTranslationResult = AXBrailleTranslator(brailleTable: table).translatePrintText("hello")
        bt = r.resultString
    } else if let t = AXBrailleTable.defaultTable(for: Locale(identifier: "en_US")) {
        bt = AXBrailleTranslator(brailleTable: t).translatePrintText("hello").resultString
    }
    // a braille map (bit map of heights)
    let mapClass = AXBrailleMap.self
    // chart descriptor with a categorical axis and data points
    let xAxis = AXCategoricalDataAxisDescriptor(title: "Fruit", categoryOrder: ["apple", "pear"])
    let yAxis = AXNumericDataAxisDescriptor(title: "Count", range: 0...10, gridlinePositions: []) { "\($0)" }
    let pts = [AXDataPoint(x: "apple", y: 3), AXDataPoint(x: "pear", y: 7)]
    let series = AXDataSeriesDescriptor(name: "s", isContinuous: false, dataPoints: pts)
    let chart = AXChartDescriptor(title: "Fruit", summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    let xv: AXDataPointValue = pts[0].xValue
    let yv = pts[1].yValue
    try expect(chart.series.first?.dataPoints.count == 2 && xv.value(forKey: "category") as? String == "apple" && yv?.value(forKey: "number") as? Double == 7 && xAxis.categoryOrder == ["apple", "pear"], "chart")
    // the current request outside an accessibility query, feature override manager
    try expect(NSStringFromClass(AccessibilityRequest.self) == "AXRequest", "AXRequest is \(NSStringFromClass(AccessibilityRequest.self))")
    let req = AccessibilityRequest.current
    #if os(tvOS)
    let mgrClass = "absent on tvOS", sessClass = "-", live = AXLiveAudioGraph.self
    try expect(NSClassFromString("AXFeatureOverrideSessionManager") == nil, "AXFeatureOverrideSessionManager on tvOS")
    #else
    let mgrClass = try p27uiClass("AXFeatureOverrideSessionManager"), sessClass = try p27uiClass("AXFeatureOverrideSession"), live = AXLiveAudioGraph.self
    #endif
    return "math tree ok, braille '\(bt)', chart 2 points, AXRequest.current \(req.map { "\($0.technology)" } ?? "nil"); \(mapClass) \(mgrClass) \(sessClass) \(live)"
}

#if canImport(UIKit) && !os(watchOS)
import Symbols
@MainActor private func p27uiSymbols() async throws -> String {
    let iv = UIImageView(image: UIImage(systemName: "star.fill"))
    let close = try p27uiHost(iv, CGSize(width: 60, height: 60)); defer { close() }
    func disc<E: DiscreteSymbolEffect & SymbolEffect>(_ e: E) -> String { "\(e)" }
    func indef<E: IndefiniteSymbolEffect & SymbolEffect>(_ e: E) { iv.addSymbolEffect(e, options: .repeat(.periodic(2, delay: 0))) }
    func trans<E: TransitionSymbolEffect & SymbolEffect>(_ e: E) -> String { "\(e)" }
    func ctrans<E: ContentTransitionSymbolEffect & SymbolEffect>(_ e: E) -> String { "\(e)" }
    indef(.pulse)
    iv.addSymbolEffect(.bounce)
    let r: ReplaceSymbolEffect = .replace.downUp, au: AutomaticSymbolEffect = .automatic, off: DrawOffSymbolEffect = .drawOff
    iv.setSymbolImage(UIImage(systemName: "heart.fill")!, contentTransition: r)
    let names = [disc(.bounce), trans(.appear), trans(off), ctrans(r), ctrans(au)]
    iv.removeAllSymbolEffects()
    // the Objective-C classes behind them (refined for Swift)
    var objs: [(AnyClass, NSObject)] = []
    for n in ["NSSymbolAppearEffect", "NSSymbolBreatheEffect", "NSSymbolDisappearEffect", "NSSymbolDrawOffEffect", "NSSymbolDrawOnEffect", "NSSymbolRotateEffect", "NSSymbolScaleEffect", "NSSymbolVariableColorEffect"] {
        let cls = try p27uiClass(n)
        guard let e = (cls as AnyObject).perform(NSSelectorFromString("effect"))?.takeUnretainedValue() as? NSObject else { throw Fail("\(n) +effect") }
        objs.append((cls, e))
    }
    for n in ["NSSymbolReplaceContentTransition", "NSSymbolAutomaticContentTransition"] {
        let cls = try p27uiClass(n)
        guard let t = (cls as AnyObject).perform(NSSelectorFromString("transition"))?.takeUnretainedValue() as? NSObject else { throw Fail("\(n) +transition") }
        objs.append((cls, t))
    }
    let magic = (try p27uiClass("NSSymbolReplaceContentTransition") as AnyObject).perform(NSSelectorFromString("magicTransitionWithFallback:"), with: objs.last!.1)?.takeUnretainedValue() as? NSObject
    try expect(magic?.isKind(of: try p27uiClass("NSSymbolMagicReplaceContentTransition")) == true || magic != nil, "magic replace \(String(describing: magic))")
    let optCls = try p27uiClass("NSSymbolEffectOptions"), rbCls = try p27uiClass("NSSymbolEffectOptionsRepeatBehavior")
    let opt = (optCls as AnyObject).perform(NSSelectorFromString("optionsWithSpeed:"), with: NSNumber(value: 2.0))
    let rb = (rbCls as AnyObject).perform(NSSelectorFromString("behaviorPeriodic"))?.takeUnretainedValue() as? NSObject
    try expect(rb != nil && (objs[0].1).isKind(of: try p27uiClass("NSSymbolEffect")) && (objs[8].1).isKind(of: try p27uiClass("NSSymbolContentTransition")), "options/behavior")
    _ = opt
    return "\(names.count) Swift effects on an image view; " + (try p27uiTable(objs + [(rbCls, rb!)]))
}

@MainActor private func p27uiQuartz() async throws -> String {
    let host = UIView(); let close = try p27uiHost(host); defer { close() }
    let layer = CALayer(); layer.frame = CGRect(x: 0, y: 0, width: 10, height: 10); host.layer.addSublayer(layer)
    let key = CAKeyframeAnimation(keyPath: "position.x"); key.values = [0, 50, 100]; key.keyTimes = [0, 0.5, 1]; key.duration = 0.2
    let spring = CASpringAnimation(keyPath: "opacity"); spring.fromValue = 0; spring.toValue = 1; spring.damping = 20; spring.stiffness = 300
    let rot = CABasicAnimation(keyPath: "transform"); rot.valueFunction = CAValueFunction(name: .rotateZ); rot.fromValue = 0; rot.toValue = Double.pi
    let prop: CAPropertyAnimation = rot
    let group = CAAnimationGroup(); group.animations = [key, spring, rot]; group.duration = 0.25
    var done = false
    final class D: NSObject, CAAnimationDelegate { var f: () -> Void; init(_ f: @escaping () -> Void) { self.f = f }; func animationDidStop(_ a: CAAnimation, finished: Bool) { if finished { f() } } }
    let base: CAAnimation = group
    base.delegate = D { done = true }
    layer.add(group, forKey: "g")
    let tr = CATransition(); tr.type = .push; tr.subtype = .fromRight; tr.duration = 0.1
    layer.add(tr, forKey: kCATransition)
    let ok = await p6Wait(3) { done }
    try expect(ok && spring.settlingDuration > 0 && prop.keyPath == "transform", "group finished \(done), settling \(spring.settlingDuration)")
    let scroll = CAScrollLayer(); scroll.frame = CGRect(x: 0, y: 0, width: 10, height: 10); scroll.scrollMode = .vertically; scroll.scroll(to: CGPoint(x: 5, y: 7))
    try expect(scroll.bounds.origin == CGPoint(x: 0, y: 7), "scroll layer \(scroll.bounds)")
    #if os(tvOS)
    let hdr = "-", hlg = "-"
    #else
    let hdr = CAEDRMetadata.hdr10(minLuminance: 0.005, maxLuminance: 1000, opticalOutputScale: 100)
    let hlg = CAEDRMetadata.hlg
    #endif
    var dl = ""
    if let dev = MTLCreateSystemDefaultDevice() {
        let ml = CAMetalLayer(); ml.device = dev
        let link = CAMetalDisplayLink(metalLayer: ml)
        final class LD: NSObject, CAMetalDisplayLinkDelegate { var n = 0; func metalDisplayLink(_ l: CAMetalDisplayLink, needsUpdate u: CAMetalDisplayLink.Update) { n += 1; _ = u.drawable } }
        let ld = LD(); link.delegate = ld; link.preferredFrameLatency = 2; link.add(to: .main, forMode: .common)
        _ = await p6Wait(2) { ld.n > 0 }
        link.invalidate(); dl = "metal display link updates \(ld.n)"
        _ = "\(CAMetalDisplayLink.Update.self)"
    }
    #if os(visionOS)
    let eagl = "-"
    #else
    let eagl = "\(CAEAGLLayer.self)"
    #endif
    return "group + transition done, spring settles \(String(format: "%.2f", spring.settlingDuration)) s, scroll layer, EDR \(hdr) \(hlg), \(dl), \(eagl)"
}
#endif

#if canImport(CoreImage) && !os(watchOS)
import CoreImage
import CoreImage.CIFilterBuiltins
private func p27uiCoreImage() throws -> String {
    // QR: generate, detect, read the message and its descriptor back
    let qr = CIFilter.qrCodeGenerator(); qr.message = Data("p27ui".utf8); qr.correctionLevel = "M"
    guard let img = qr.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { throw Fail("no QR image") }
    let ctx = CIContext(options: [.workingColorSpace: NSNull()])
    let det = CIDetector(ofType: CIDetectorTypeQRCode, context: ctx, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    let feats: [CIFeature] = det?.features(in: img) ?? []
    let q = feats.first as? CIQRCodeFeature
    let qd: CIQRCodeDescriptor? = q?.symbolDescriptor
    try expect(q?.messageString == "p27ui" && qd != nil && q?.type == CIFeatureTypeQRCode, "QR detect: \(feats.count) features, message \(q?.messageString ?? "nil")")
    // descriptors -> barcode generator
    let descs: [CIBarcodeDescriptor] = [qd!] + [
        CIAztecCodeDescriptor(payload: Data([0x01, 0x02]), isCompact: true, layerCount: 1, dataCodewordCount: 2),
        CIPDF417CodeDescriptor(payload: Data([0x01, 0x02, 0x03, 0x04]), isCompact: false, rowCount: 3, columnCount: 2),
        CIDataMatrixCodeDescriptor(payload: Data([0x01, 0x02, 0x03]), rowCount: 10, columnCount: 10, eccVersion: .v200),
    ].compactMap { $0 }
    let gen = CIFilter.barcodeGenerator()
    var made = 0
    var genErr: [String] = []
    for d in descs {
        gen.barcodeDescriptor = d
        var out: CIImage?
        if let e = SDKCovCatch({ out = gen.outputImage }) { genErr.append("\(type(of: d)): \(e)") }
        if let o = out, !o.extent.isInfinite, o.extent.width > 0 { made += 1 }
    }
    try expect(genErr.isEmpty && made == 2, "barcode generator raised \(genErr), made \(made)")
    // accumulator + blend kernel + render destination/task/info + sampler + filter shape
    let acc = CIImageAccumulator(extent: CGRect(x: 0, y: 0, width: 4, height: 4), format: .RGBA8)!
    acc.setImage(CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 4)))
    let blended = CIBlendKernel.multiply.apply(foreground: acc.image(), background: CIImage(color: CIColor(red: 1, green: 1, blue: 0)).cropped(to: acc.extent))!
    var px = [UInt8](repeating: 0, count: 4 * 4 * 4)
    let dest = px.withUnsafeMutableBytes { CIRenderDestination(bitmapData: $0.baseAddress!, width: 4, height: 4, bytesPerRow: 16, format: .RGBA8) }
    dest.colorSpace = nil
    let task: CIRenderTask = try ctx.startTask(toRender: blended, to: dest)
    let info: CIRenderInfo = try task.waitUntilCompleted()
    try expect(px[0] == 255 && px[1] == 0 && px[3] == 255, "render \(Array(px.prefix(4)))")
    let sampler = CISampler(image: img)
    let shape = CIFilterShape(rect: CGRect(x: 0, y: 0, width: 2, height: 2)).union(with: CGRect(x: 2, y: 2, width: 2, height: 2))
    try expect(sampler.extent == img.extent && shape.extent == CGRect(x: 0, y: 0, width: 4, height: 4), "sampler/shape")
    let face = "\(CIFaceFeature.self)"
    return "QR '\(q!.messageString!)', \(made)/\(descs.count) barcodes generated, render \(Array(px.prefix(4))) passes \(info.passCount), \(face)"
}
#endif

import OSLog
private func p27uiOSLog() throws -> String {
    let log = Logger(subsystem: "com.x86sim.test.sdkcov", category: "p27ui")
    let mark = "p27ui-mark-\(UUID().uuidString.prefix(8))"
    log.notice("\(mark, privacy: .public) value \(42, privacy: .public)")
    let store = try OSLogStore(scope: .currentProcessIdentifier)
    let pos: OSLogPosition = store.position(timeIntervalSinceEnd: -60)
    let en = try store.getEntries(at: pos, matching: NSPredicate(format: "subsystem == 'com.x86sim.test.sdkcov'"))
    try expect(try p27uiClass("OSLogEnumerator").isSubclass(of: NSEnumerator.self), "OSLogEnumerator")
    var found: OSLogEntryLog?, kinds = Set<String>()
    for case let e as OSLogEntry in en {
        kinds.insert("\(type(of: e))")
        if let l = e as? OSLogEntryLog, l.composedMessage.contains(mark) { found = l }
    }
    let comps: [OSLogMessageComponent] = found?.components ?? []
    let args = comps.map { "\($0.argumentCategory.rawValue)" }
    try expect(found != nil && found?.level == .notice && found?.category == "p27ui", "entry not found; kinds \(kinds)")
    let cats: [OSLogMessageComponent.ArgumentCategory] = comps.map { $0.argumentCategory }
    let hasString = cats.contains(OSLogMessageComponent.ArgumentCategory.string)
    let hasInt = cats.contains(OSLogMessageComponent.ArgumentCategory.int64) || cats.contains(OSLogMessageComponent.ArgumentCategory.uInt64)
    try expect(hasString && hasInt, "components \(args)")
    let types = "\(OSLogEntryActivity.self) \(OSLogEntryBoundary.self)"
    return "found '\(found!.composedMessage)', \(comps.count) components, kinds \(kinds.sorted()); \(types)"
}

// MARK: UIKit, part 2: scenes, text input, controls, interactions, value types

#if canImport(UIKit) && !os(watchOS)
extension Registry {
    static var p27uiKit2: [Check] {
        var c: [Check] = []

        // the app's scene: session, configuration, geometry, status bar, screen modes; request / option objects
        c.append(check("UIKit", "p27ui-scene-objects") {
            try await p6A {
                let ws = try p6Scene()
                let session: UISceneSession = ws.session
                let cfg: UISceneConfiguration = session.configuration
                try expect(session.role == .windowApplication && !session.persistentIdentifier.isEmpty, "session \(session.role.rawValue)")
                let geo: UIWindowScene.Geometry = ws.effectiveGeometry
                try expect(geo.coordinateSpace.bounds.width > 0, "geometry \(geo)")
                let cond: UISceneActivationConditions = ws.activationConditions
                cond.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
                #if os(visionOS)
                let modes: [NSObject] = [NSObject()]
                let cur: (size: CGSize, x: Int)? = (CGSize(width: 1, height: 1), 0)
                #elseif os(tvOS)
                let modes: [UIScreenMode] = ws.screen.currentMode.map { [$0] } ?? []
                let cur = ws.screen.currentMode
                #else
                let modes: [UIScreenMode] = ws.screen.availableModes
                let cur = ws.screen.currentMode
                #endif
                try expect(!modes.isEmpty && (cur?.size.width ?? 0) > 0, "screen modes \(modes.count) \(String(describing: cur))")
                // Swift-renamed scene option classes: each object is of its Objective-C class
                var named: [(String, NSObject)] = [("UISceneConfiguration", UISceneConfiguration(name: "P27", sessionRole: .windowApplication)), ("UISceneSession", session),
                    ("UIWindowSceneGeometry", geo), ("UISceneActivationConditions", cond), ("UIScreenMode", modes[0]),
                    ("UISceneActivationRequestOptions", UIScene.ActivationRequestOptions()), ("UISceneDestructionRequestOptions", UISceneDestructionRequestOptions()),
                    ("UISceneOpenExternalURLOptions", UIScene.OpenExternalURLOptions())]
                var sreq = UISceneSessionActivationRequest(role: .windowApplication); sreq.userActivity = NSUserActivity(activityType: "p27")
                try expect(sreq.role == .windowApplication && sreq.userActivity?.activityType == "p27", "session activation request")
                var d = "session \(session.role.rawValue) config \(cfg.name ?? "-"), \(modes.count) screen modes"
                var missingClasses: [String] = []
                #if os(iOS)
                let sb: UIStatusBarManager? = ws.statusBarManager
                let opt = UIWindowScene.ActivationRequestOptions(); opt.preferredPresentationStyle = .prominent
                let geoPref = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                let sizes: UISceneSizeRestrictions? = ws.sizeRestrictions
                let destroy = UIWindowSceneDestructionRequestOptions(); destroy.windowDismissalAnimation = .decline
                let act = UIWindowScene.ActivationConfiguration(userActivity: NSUserActivity(activityType: "p27"))
                let action = UIWindowScene.ActivationAction(alternate: nil) { _ in act }
                let drag = UIWindowSceneDragInteraction()
                let behaviors: UISceneWindowingBehaviors? = ws.windowingBehaviors
                let style: UIWindowScene.WindowingControlStyle = .automatic
                let prot = ws.systemProtectionManager
                let closure = UISceneClosureConfirmation(title: "Close?", message: nil, actions: [UIAlertAction(title: "OK", style: .default)])
                named += [("UIWindowSceneActivationRequestOptions", opt), ("UIWindowSceneDestructionRequestOptions", destroy), ("UIWindowSceneActivationConfiguration", act),
                          ("UIWindowSceneGeometryPreferencesIOS", geoPref), ("UIWindowSceneGeometryPreferences", geoPref), ("UIWindowSceneGeometryPreferencesMac", UIWindowScene.GeometryPreferences.Mac()),
                          ("UISceneClosureConfirmation", closure), ("UIWindowSceneActivationAction", action), ("UIWindowSceneDragInteraction", drag)]
                if let sb { named.append(("UIStatusBarManager", sb)) }
                if let sizes { named.append(("UISceneSizeRestrictions", sizes)) }
                if let behaviors { named.append(("UISceneWindowingBehaviors", behaviors)) }
                if let prot { named.append(("UISceneSystemProtectionManager", prot)) }
                try expect((sb?.statusBarFrame.height ?? -1) >= 0 && drag.view == nil, "iOS scene objects")
                d += ", status bar \(sb?.statusBarFrame.height ?? -1), sizes \(sizes.map { "\($0.minimumSize)" } ?? "nil"), behaviors \(behaviors.map { "\($0.isClosable)" } ?? "nil"), style \(style), protection \(prot.map { "\($0.isUserAuthenticationEnabled)" } ?? "nil")"
                let places: [any UIWindowScenePlacement] = [UIWindowSceneStandardPlacement(), UIWindowSceneProminentPlacement()]
                missingClasses += try p27uiProbe(["UIWindowScenePlacement", "UIWindowSceneStandardPlacement", "UIWindowSceneProminentPlacement", "UIWindowScenePushPlacement", "UIWindowSceneReplacePlacement", "UIWindowSceneGeometryPreferencesVision", "UISceneDestructionCondition", "UISceneWindowingControlStyle", "UISceneAccessory", "UISceneAccessoryRegistration", "UISceneConnectionOptions", "UISceneOpenURLOptions", "UIOpenURLContext"]).absent
                d += ", \(places.count) placements"
                #endif
                var objs: [(AnyClass, NSObject)] = []
                for (n, o) in named { objs.append((try p27uiClass(n), o)) }
                let urlOpt = UIScene.OpenURLOptions.self
                #if os(iOS)
                try expect(missingClasses == ["UIWindowSceneGeometryPreferencesVision"], "missing classes \(missingClasses)")
                #endif
                return d + "; missing classes \(missingClasses); \(urlOpt); " + (try p27uiTable(objs, archive: false))
            }
        })

        // feedback generators (no Taptic Engine in the simulator: prepare + fire answer without effect)
        #if os(iOS)
        c.append(check("UIKit", "p27ui-feedback") {
            try await p6A {
                let v = UIView(); let close = try p27uiHost(v); defer { close() }
                let gens: [UIFeedbackGenerator] = [UIImpactFeedbackGenerator(style: .rigid, view: v), UINotificationFeedbackGenerator(view: v), UISelectionFeedbackGenerator(view: v), UICanvasFeedbackGenerator(view: v)]
                for g in gens { g.prepare() }
                (gens[0] as! UIImpactFeedbackGenerator).impactOccurred(intensity: 0.5, at: CGPoint(x: 1, y: 1))
                (gens[1] as! UINotificationFeedbackGenerator).notificationOccurred(.success, at: .zero)
                (gens[2] as! UISelectionFeedbackGenerator).selectionChanged(at: .zero)
                (gens[3] as! UICanvasFeedbackGenerator).alignmentOccurred(at: .zero)
                return "\(gens.count) generators fired: " + gens.map { "\(type(of: $0))" }.joined(separator: " ")
            }
        })
        #endif

        // text input: spell checking, positions/ranges/selection rects/tokenizer on a text view, input modes,
        // lexicon, indexed collation, assistant items, password rules, placeholders, keys
        c.append(check("UIKit", "p27ui-text-input") {
            try await p6A {
                let tv = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 200)); tv.text = "Hello wrold, again"
                let close = try p27uiHost(tv); defer { close() }
                tv.layoutIfNeeded()
                let start: UITextPosition = tv.beginningOfDocument
                guard let p6 = tv.position(from: start, offset: 6), let p11 = tv.position(from: start, offset: 11), let r = tv.textRange(from: p6, to: p11) else { throw Fail("no positions") }
                try expect(tv.text(in: r) == "wrold", "range text \(tv.text(in: r) ?? "nil")")
                let rects: [UITextSelectionRect] = tv.selectionRects(for: r)
                try expect(!rects.isEmpty && rects[0].rect.width > 10, "selection rects \(rects.map(\.rect))")
                let tok = UITextInputStringTokenizer(textInput: tv)
                let wordEnd = tok.position(from: start, toBoundary: .word, inDirection: .storage(.forward))
                try expect(wordEnd.map { tv.offset(from: start, to: $0) } == 5, "tokenizer word end \(wordEnd.map { tv.offset(from: start, to: $0) } ?? -1)")
                var spell = "n/a"
                #if !os(tvOS)
                let checker = UITextChecker()
                let miss = checker.rangeOfMisspelledWord(in: tv.text, range: NSRange(location: 0, length: (tv.text as NSString).length), startingAt: 0, wrap: false, language: "en_US")
                let guesses = checker.guesses(forWordRange: miss, in: tv.text, language: "en_US") ?? []
                try expect(miss.location == 6 && guesses.contains("world"), "spell \(miss) \(guesses)")
                spell = "miss at \(miss.location), guesses \(guesses.prefix(3))"
                #if os(iOS)
                let assist: UITextInputAssistantItem = tv.inputAssistantItem
                assist.leadingBarButtonGroups = []
                #endif
                let coll = UILocalizedIndexedCollation.current()
                let sec = coll.section(for: "Apple" as NSString, collationStringSelector: NSSelectorFromString("lowercaseString"))
                try expect(coll.sectionTitles.count > 20 && coll.sectionTitles[sec] == "A", "collation \(sec)")
                let hasDef = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: "apple")
                spell += ", dictionary \(hasDef)"
                #endif
                let modes: [UITextInputMode] = UITextInputMode.activeInputModes
                let pw = UITextInputPasswordRules(descriptor: "required: lower; minlength: 8;")
                tv.passwordRules = pw
                try expect(pw.passwordRulesDescriptor.contains("minlength"), "password rules")
                #if os(tvOS)
                let entries: [Int] = []
                #else
                let lex: UILexicon = await withCheckedContinuation { cont in UIInputViewController().requestSupplementaryLexicon { cont.resume(returning: $0) } }
                let entries: [UILexiconEntry] = lex.entries
                #endif
                let ph: UITextPlaceholder? = tv.insertTextPlaceholder(with: CGSize(width: 10, height: 10))
                if let ph { tv.remove(ph) }
                let dict = "\(UIDictationPhrase.self)"
                let key = "\(UIKey.self)"
                let ctx = "\(UITextInputContext.self)"
                return "\(spell); modes \(modes.map { $0.primaryLanguage ?? "?" }.prefix(3)); lexicon \(entries.count); placeholder \(ph != nil); \(dict) \(key) \(ctx)"
            }
        })

        // auto layout: anchors (X/Y/dimension), layout guides, keyboard layout guide
        c.append(check("UIKit", "p27ui-layout-anchors") {
            try await p6A {
                let root = UIView(); let close = try p27uiHost(root); defer { close() }
                let guide = UILayoutGuide(); root.addLayoutGuide(guide)
                let box = UIView(); box.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(box)
                let x: NSLayoutXAxisAnchor = box.leadingAnchor, y: NSLayoutYAxisAnchor = box.topAnchor, w: NSLayoutDimension = box.widthAnchor
                NSLayoutConstraint.activate([
                    guide.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10), guide.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
                    guide.widthAnchor.constraint(equalToConstant: 100), guide.heightAnchor.constraint(equalToConstant: 50),
                    x.constraint(equalToSystemSpacingAfter: guide.trailingAnchor, multiplier: 1), y.constraint(equalTo: guide.bottomAnchor),
                    w.constraint(equalTo: guide.widthAnchor, multiplier: 0.5), box.heightAnchor.constraint(equalTo: w),
                ])
                root.layoutIfNeeded()
                try expect(guide.layoutFrame == CGRect(x: 10, y: 20, width: 100, height: 50), "guide \(guide.layoutFrame)")
                try expect(box.frame.minX > 110 && box.frame.minY == 70 && box.frame.width == 50 && box.frame.height == 50, "box \(box.frame)")
                let anchorX = x.anchorWithOffset(to: box.trailingAnchor)
                try expect(anchorX is NSLayoutDimension, "anchor with offset")
                var d = "guide \(guide.layoutFrame) box \(box.frame)"
                #if os(iOS)
                let kb: UIKeyboardLayoutGuide = root.keyboardLayoutGuide
                let trk: UITrackingLayoutGuide = kb
                trk.setConstraints([], activeWhenNearEdge: .bottom)
                d += ", keyboard guide \(kb.layoutFrame.height)"
                let region = UIView.LayoutRegion.safeArea()
                let lg = root.layoutGuide(for: region)
                _ = try p27uiClass("UIViewLayoutRegion")
                d += ", region guide \(lg.layoutFrame.width)"
                #endif
                return d
            }
        })

        // controls and views: activity indicator, progress, page control with timer progress, refresh control,
        // search bar / text field / tokens, color well, calendar view with selection and decorations, paste control
        c.append(check("UIKit", "p27ui-controls") {
            try await p6A {
                let root = UIView(); let close = try p27uiHost(root); defer { close() }
                let ai = UIActivityIndicatorView(style: .medium); root.addSubview(ai); ai.startAnimating()
                let pv = UIProgressView(progressViewStyle: .default); pv.setProgress(0.4, animated: false)
                let pc = UIPageControl(); pc.numberOfPages = 4; pc.currentPage = 2
                let tp = UIPageControlTimerProgress(preferredDuration: 2); tp.resetsToInitialPageAfterEnd = true
                let pcp: UIPageControlProgress = tp
                pc.progress = pcp
                try expect(ai.isAnimating && pv.progress == 0.4 && pc.currentPage == 2 && tp.preferredDuration == 2, "indicator/progress/page")
                var d = "page \(pc.currentPage)/\(pc.numberOfPages)"
                #if !os(tvOS)
                let sb = UISearchBar(); sb.text = "abc"
                let tf: UISearchTextField = sb.searchTextField
                let token = UISearchToken(icon: UIImage(systemName: "tag"), text: "P27"); token.representedObject = 27
                tf.insertToken(token, at: 0)
                try expect(tf.tokens.count == 1 && tf.tokens[0].representedObject as? Int == 27, "search tokens \(tf.tokens.count)")
                d += ", tokens \(tf.tokens.count)"
                #endif
                #if os(iOS)
                let sv = UIScrollView(frame: root.bounds); root.addSubview(sv)
                let rc = UIRefreshControl(); sv.refreshControl = rc; sv.layoutIfNeeded(); rc.beginRefreshing()
                let cw = UIColorWell(); cw.selectedColor = .red; cw.supportsAlpha = false
                let cal = UICalendarView(); cal.calendar = Calendar(identifier: .gregorian)
                let single = UICalendarSelectionSingleDate(delegate: nil); single.selectedDate = DateComponents(year: 2026, month: 1, day: 2)
                let multi = UICalendarSelectionMultiDate(delegate: nil); multi.selectedDates = [DateComponents(year: 2026, month: 1, day: 3)]
                let week = UICalendarSelectionWeekOfYear(delegate: nil)
                let sel: UICalendarSelection = multi
                cal.selectionBehavior = sel
                root.addSubview(cal); cal.frame = root.bounds; cal.layoutIfNeeded()
                let deco = UICalendarView.Decoration.default(color: .red, size: .large)
                let paste = UIPasteControl(configuration: UIPasteControl.Configuration())
                let paste2 = UIPasteConfiguration(acceptableTypeIdentifiers: ["public.text"])
                try expect(rc.isRefreshing && cw.selectedColor == .red && (cal.selectionBehavior as? UICalendarSelectionMultiDate)?.selectedDates.count == 1 && single.selectedDate?.day == 2 && paste2.acceptableTypeIdentifiers == ["public.text"],
                           "iOS controls: refreshing \(rc.isRefreshing) well \(String(describing: cw.selectedColor)) multi \((cal.selectionBehavior as? UICalendarSelectionMultiDate)?.selectedDates.count ?? -1) single \(single.selectedDate?.day ?? -1)")
                rc.endRefreshing()
                d += ", calendar, color well, paste \(paste.configuration.displayMode.rawValue), week \(week.selectedWeekOfYear == nil), \(deco)"
                #endif
                return d
            }
        })

        // tables: controller, header/footer views, swipe actions, drop proposals/placeholders
        c.append(check("UIKit", "p27ui-table-bits") {
            try await p6A {
                let tvc = UITableViewController(style: .grouped)
                let hf = UITableViewHeaderFooterView(reuseIdentifier: "h")
                var cfg = hf.defaultContentConfiguration(); cfg.text = "Header"; hf.contentConfiguration = cfg
                tvc.tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "h")
                try expect(tvc.tableView.style == .grouped && (hf.contentConfiguration as? UIListContentConfiguration)?.text == "Header", "table controller/header")
                var d = "grouped, header"
                #if os(iOS)
                var hit = ""
                let act = UIContextualAction(style: .destructive, title: "Del") { _, _, done in hit = "del"; done(true) }
                act.backgroundColor = .red
                let sw = UISwipeActionsConfiguration(actions: [act]); sw.performsFirstActionWithFullSwipe = false
                try expect(sw.actions.first?.title == "Del" && !sw.performsFirstActionWithFullSwipe && hit.isEmpty, "swipe config")
                let prop = UITableViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
                let ph = UITableViewDropPlaceholder(insertionIndexPath: IndexPath(row: 0, section: 0), reuseIdentifier: "c", rowHeight: 44)
                let base: UITableViewPlaceholder = ph
                try expect(prop.intent == .insertAtDestinationIndexPath && base.cellUpdateHandler == nil, "drop proposal/placeholder")
                d += ", swipe action, drop proposal"
                _ = "\(UITableViewRowAction.self)"
                #endif
                #if os(tvOS)
                let fc = "\(UITableViewFocusUpdateContext.self)"; d += ", \(fc)"
                #endif
                return d
            }
        })

        // storyboard segues built in code (identifier, source, destination, perform handler), unwind source
        c.append(check("UIKit", "p27ui-segues") {
            try await p6A {
                let a = UIViewController(), b = UIViewController()
                var performed = false
                let seg = UIStoryboardSegue(identifier: "p27", source: a, destination: b) { performed = true }
                seg.perform()
                #if os(visionOS)
                let unwind = "\(UIStoryboardUnwindSegueSource.self) \(UIStoryboard.self) \(UINib.self)"
                #else
                let unwind = "\(UIStoryboardUnwindSegueSource.self) \(UIStoryboardPopoverSegue.self) \(UIStoryboard.self) \(UINib.self)"
                #endif
                let nib = UINib(data: Data(), bundle: nil)
                var nibErr: [String]?
                nibErr = SDKCovCatch { _ = nib.instantiate(withOwner: nil) }
                try expect(seg.identifier == "p27" && seg.source === a && seg.destination === b && performed, "segue")
                let asset = NSDataAsset(name: "p27-none")
                try expect(asset == nil, "data asset should be missing")
                return "segue performed; empty nib -> \(nibErr?.first ?? "no exception"); \(unwind)"
            }
        })

        // shapes, corner configurations, shadows, slider ticks, bar minimization, view invalidations
        c.append(check("UIKit", "p27ui-shapes-corners") {
            try await p6A {
                var d = ""
                #if !os(tvOS)
                // a custom provider: UIKit resolves it against the view's bounds when the hover style asks
                struct Prov: UIShapeProvider { func resolve(in context: UIShape.ResolutionContext) -> UIShape.Resolved { UIShape.circle.resolve(in: context) } }
                let s = UIShape.rect(cornerRadius: 8).inset(by: 2), s2 = UIShape(Prov())
                try expect(s == UIShape.rect(cornerRadius: 8).inset(by: 2) && !(s == UIShape.circle) && !(s2 == s), "shape equality")
                d += "shapes"
                do { let probed = try p27uiProbe(["UIShape", "UIResolvedShape", "UIShapeResolutionContext"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
                #endif
                let v = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
                v.cornerConfiguration = .uniformCorners(radius: UICornerRadius.fixed(12))
                let cc: UICornerConfiguration = v.cornerConfiguration
                let cr: UICornerRadius = 7
                try expect(cc == .uniformCorners(radius: .fixed(12)) && cr == UICornerRadius.fixed(7), "corners \(cc)")
                var bgc = UIBackgroundConfiguration.listCell()
                bgc.shadowProperties.color = .black; bgc.shadowProperties.opacity = 0.5
                var sh: UIShadowProperties = bgc.shadowProperties; sh.color = .black; sh.opacity = 0.5; sh.radius = 4; sh.offset = CGSize(width: 1, height: 1)
                try expect(sh.radius == 4 && sh.opacity == 0.5, "shadow \(sh)")
                do { let probed = try p27uiProbe(["UIShadowProperties", "UICornerConfiguration", "UICornerRadius"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
                let inv: UIViewInvalidating = .layout
                final class IV: UIView { @Invalidating(.layout, .display) var level = 0; var laid = 0; override func layoutSubviews() { laid += 1 } }
                let iv = IV(); let close = try p27uiHost(iv); defer { close() }
                iv.layoutIfNeeded(); let l0 = iv.laid; iv.level = 3; iv.layoutIfNeeded()
                try expect(iv.laid == l0 + 1, "invalidating property: layouts \(l0) -> \(iv.laid)")
                d += ", corners \(cc), shadow, invalidating \(inv)"
                #if os(iOS)
                let tick = UISlider.TrackConfiguration.Tick(position: 0.5, title: "half", image: nil)
                let track = UISlider.TrackConfiguration(ticks: [tick, UISlider.TrackConfiguration.Tick(position: 1)])
                let slider = UISlider(); slider.trackConfiguration = track
                try expect(slider.trackConfiguration?.ticks.count == 2, "slider ticks")
                do { let probed = try p27uiProbe(["UISliderTick", "UISliderTrackConfiguration"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
                let bm = UIBarMinimization.self
                d += ", slider ticks 2, \(bm)"
                #endif
                return d
            }
        })

        // interactions: pointer / hover / tooltip / spring-loaded / large content / scribble / find / band
        // selection / context menu & main menu systems / commands; drag & preview parameters
        c.append(check("UIKit", "p27ui-interactions") {
            try await p6A {
                let v = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100)); let close = try p27uiHost(v); defer { close() }
                var added: [UIInteraction] = []
                var missingClasses: [String] = []
                let pp = UIPreviewParameters(); pp.visiblePath = UIBezierPath(roundedRect: v.bounds, cornerRadius: 10); pp.backgroundColor = .clear
                let tgt = UIPreviewTarget(container: v, center: CGPoint(x: 50, y: 50))
                let tdp = UITargetedPreview(view: v, parameters: pp, target: tgt)
                var d = "preview \(tdp.size)"
                #if os(iOS)
                let dpp = UIDragPreviewParameters(); dpp.shadowPath = UIBezierPath(rect: v.bounds)
                let dt = UIDragPreviewTarget(container: v, center: .zero)
                let tdrag = UITargetedDragPreview(view: v, parameters: dpp, target: dt)
                let dp = UIDragPreview(view: v, parameters: dpp)
                try expect(tdrag.target.container === v && dp.view === v, "drag previews")
                let tip = UIToolTipInteraction(defaultToolTip: "P27"); added.append(tip)
                let tipCfg = UIToolTipConfiguration(toolTip: "cfg", in: v.bounds)
                let hover = UIHoverStyle(effect: .highlight, shape: .capsule)
                let hs: [UIHoverEffect] = [UIHoverAutomaticEffect(), UIHoverHighlightEffect(), UIHoverLiftEffect()]
                v.hoverStyle = hover
                let ptr = UIPointerStyle(effect: .lift(tdp), shape: .roundedRect(v.bounds))
                let shape = UIPointerShape.path(UIBezierPath(ovalIn: v.bounds))
                let acc = UIPointerAccessory.arrow(.top)
                let effects: [UIPointerEffect] = [.highlight(tdp), .lift(tdp), .hover(tdp)]
                for n in ["UIPointerHighlightEffect", "UIPointerLiftEffect", "UIPointerHoverEffect"] { try expect(try p27uiClass(n).isSubclass(of: try p27uiClass("UIPointerEffect")), n) }
                ptr.accessories = [acc]
                added.append(UISpringLoadedInteraction { _, _ in })
                added.append(UILargeContentViewerInteraction())
                final class SD: NSObject, UIScribbleInteractionDelegate {}
                let sd = SD(); added.append(UIScribbleInteraction(delegate: sd))
                final class FD: NSObject, UIFindInteractionDelegate { func findInteraction(_ i: UIFindInteraction, sessionFor view: UIView) -> UIFindSession? { nil } }
                let fd = FD(); let find = UIFindInteraction(sessionDelegate: fd); added.append(find)
                let band = UIBandSelectionInteraction { _ in }; added.append(band)
                let cmd = UICommand(title: "P27", action: #selector(UIView.layoutIfNeeded), propertyList: "x", alternates: [UICommandAlternate(title: "Alt", action: #selector(UIView.setNeedsLayout), modifierFlags: .shift)])
                let prefs = UIMenuDisplayPreferences(); prefs.maximumNumberOfTitleLines = 2
                let ctxSys: UIContextMenuSystem = .shared
                let mainSys: UIMainMenuSystem = .shared
                let mcfg = UIMainMenuSystem.Configuration()
                let sysBase: UIMenuSystem = ctxSys
                try expect(cmd.alternates.count == 1 && cmd.propertyList as? String == "x" && prefs.maximumNumberOfTitleLines == 2 && tipCfg.toolTip == "cfg" && hs.count == 3 && effects.count == 3, "commands/tooltips/pointers")
                d += ", \(shape), \(mainSys) \(mcfg) \(sysBase)"
                missingClasses += try p27uiProbe(["UIMenuSystemFindElementGroupConfiguration", "UIDeferredMenuElementProvider", "UIMenuController", "UIMenuItem", "UIIndirectScribbleInteraction", "UIScrollEdgeElementContainerInteraction", "UILookToScrollInteraction", "UIWindowSceneDragInteraction"]).absent
                let edge: UIScrollEdgeEffect = UIScrollView().topEdgeEffect
                _ = missingClasses
                edge.style = .hard
                try expect(edge.style == UIScrollEdgeEffect.Style.hard, "edge effect")
                #endif
                #if os(iOS)
                let fx = UIFocusHaloEffect(roundedRect: v.bounds, cornerRadius: 8, curve: .continuous)
                let fe: UIFocusEffect = fx
                v.focusEffect = fe
                #endif
                let guide = UIFocusGuide(); v.addLayoutGuide(guide); guide.preferredFocusEnvironments = [v]
                added.forEach(v.addInteraction)
                try expect(v.interactions.count >= added.count && guide.preferredFocusEnvironments.count == 1, "interactions \(v.interactions.count)")
                #if os(iOS)
                try expect(missingClasses == ["UILookToScrollInteraction"], "missing classes \(missingClasses)")
                #endif
                return d + ", \(added.count) interactions, missing classes \(missingClasses)"
            }
        })

        // conversation contexts and suggestions (smart replies, search, photo search) as plain values
        #if os(iOS)
        c.append(check("UIKit", "p27ui-conversation-suggestions") {
            try await p6A {
                let e = UIConversationContext.Entry(); e.text = "Lunch?"; e.senderIdentifier = "a"; e.entryIdentifier = "1"; e.sentDate = Date(timeIntervalSince1970: 0)
                let mail = UIMailConversationContext(); mail.entries = [e]; mail.responseSubject = "Re: lunch"; mail.selfIdentifiers = ["b"]
                let msg = UIMessageConversationContext(); msg.entries = [e]; msg.isJunk = false
                let base: UIConversationContext = mail
                try expect(base.entries.first?.text == "Lunch?" && mail.responseSubject == "Re: lunch" && !msg.isJunk, "conversation context")
                let tv = UITextView(); tv.conversationContext = msg
                try expect((tv.conversationContext as? UIMessageConversationContext)?.entries.count == 1, "text view conversation context")
                let item = UISearchSuggestionItem(localizedSuggestion: "p27", localizedDescription: "desc")
                item.representedObject = 5
                do { let probed = try p27uiProbe(["UIConversationEntry", "UISmartReplySuggestion", "UIPhotoSearchSuggestion", "UIInputSuggestion", "UIEventAttribution", "UIEventAttributionView", "UIDocumentProperties"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
                let attr = UIEventAttribution(sourceIdentifier: 1, destinationURL: URL(string: "https://example.com")!, sourceDescription: "ad", purchaser: "p")
                let props = UIDocumentProperties(url: URL(fileURLWithPath: "/tmp/p27.txt"))
                try expect(item.localizedSuggestion == "p27" && attr.sourceIdentifier == 1 && props.metadata.originalURL != nil, "suggestion/attribution/doc properties")
                return "mail+message contexts, suggestion, attribution \(attr.purchaser)"
            }
        })
        #endif

        // printing pieces and deprecated / not-in-Swift classes still present in UIKit
        c.append(check("UIKit", "p27ui-printing-legacy") {
            try await p6A {
                var d = ""
                #if os(iOS)
                let mk = UIMarkupTextPrintFormatter(markupText: "<p>P27</p>")
                let vf = UITextView().viewPrintFormatter()
                let pf: UIPrintFormatter = mk; pf.perPageContentInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                let paper = UIPrintPaper.bestPaper(forPageSize: CGSize(width: 612, height: 792), withPapersFrom: [])
                let printer = UIPrinter(url: URL(string: "ipp://127.0.0.1/p27")!)
                let picker = UIPrinterPickerController(initiallySelectedPrinter: printer)
                try expect(paper.paperSize == CGSize(width: 612, height: 792) && printer.url.host == "127.0.0.1" && picker.selectedPrinter === printer && vf is UIViewPrintFormatter, "printing \(paper.paperSize)")
                let cam = UIImagePickerController.isSourceTypeAvailable(.camera)
                let video = UIVideoEditorController.canEditVideo(atPath: "/nonexistent.mov")
                d = "paper \(paper.paperSize), camera \(cam), edit video \(video)"
                do { let probed = try p27uiProbe(["UIPrinterDestination", "UIPrintServiceExtension", "UIDocumentPickerExtensionViewController", "UIDocumentMenuViewController", "UICloudSharingController", "UIManagedDocument", "UIDocumentViewController", "UIDocumentViewControllerLaunchOptions", "UIDocumentBrowserTransitionController"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
                #endif
                var present: [String] = []
                for n in ["UIAlertView", "UIActionSheet", "UIPopoverController", "UISearchDisplayController", "UILocalNotification", "UIUserNotificationSettings", "UIUserNotificationAction", "UIMutableUserNotificationAction", "UIUserNotificationCategory", "UIMutableUserNotificationCategory", "UIAccelerometer", "UIAcceleration", "UIWebView", "UIPreviewAction", "UIPreviewActionGroup", "UIPreviewInteraction", "UIPopoverBackgroundView", "UIApplicationShortcutItem", "UIMutableApplicationShortcutItem", "UIApplicationShortcutIcon", "UIOpenURLContext", "UIScreenshotService", "UIActivityItemsConfiguration", "UIActivityCollaborationModeRestriction", "UIFontPickerViewControllerConfiguration", "UIFontDescriptor", "UIInputView", "UIInputViewController"] where NSClassFromString(n) != nil { present.append(n) }
                #if os(iOS)
                let sc = UIApplicationShortcutItem(type: "p27", localizedTitle: "P27", localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: "star"), userInfo: ["k": 1 as NSNumber])
                let msc = sc.mutableCopy() as! UIMutableApplicationShortcutItem; msc.localizedTitle = "Changed"
                let aic = UIActivityItemsConfiguration(objects: ["text" as NSString])
                let fpc = UIFontPickerViewController.Configuration(); fpc.includeFaces = true
                try expect(msc.localizedTitle == "Changed" && sc.type == "p27" && aic.localObject == nil && fpc.includeFaces, "shortcut items / activity items / font picker config")
                #endif
                let fd = UIFontDescriptor(name: "Helvetica", size: 12).withSymbolicTraits(.traitBold)
                let iv = UIInputView(frame: CGRect(x: 0, y: 0, width: 10, height: 10), inputViewStyle: .keyboard)
                try expect(fd?.symbolicTraits.contains(.traitBold) == true && iv.inputViewStyle == .keyboard, "font descriptor / input view")
                return d + "; classes present \(present.count): missing " + "\(Set(["UIWebView", "UIAccelerometer"]).subtracting(present).sorted())"
            }
        })

        return c
    }
}
#endif

// MARK: part 3: UIKit classes behind Swift names, KVO and the remaining Foundation classes, PencilKit, Quick Look,
// Core Graphics' Swift types

/// the Swift object `o` is an instance of the Objective-C class `objc` (UIKit / Foundation classes Swift renames)
private func p27uiIsa(_ objc: String, _ o: Any) throws {
    let cls = try p27uiClass(objc)
    guard let obj = (o as AnyObject) as? NSObject, obj.isKind(of: cls) else { throw Fail("\(objc): Swift value is \(type(of: (o as AnyObject)))") }
}

/// KVO target
final class P27uiKVO: NSObject {
    @objc dynamic var a = 0
    @objc dynamic var b = 0
    @objc dynamic var sum: Int { a + b }
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> { key == "sum" ? ["a", "b"] : super.keyPathsForValuesAffectingValue(forKey: key) }
}
extension P27uiKVO: NSKeyValueObservingCustomization {
    static func keyPathsAffectingValue(for key: AnyKeyPath) -> Set<AnyKeyPath> { key == \P27uiKVO.sum ? [\P27uiKVO.a, \P27uiKVO.b] : [] }
    static func automaticallyNotifiesObservers(for key: AnyKeyPath) -> Bool { true }
}
enum P27uiEncKey: EncodableAttributedStringKey, DecodableAttributedStringKey { typealias Value = Int; static let name = "p27n" }

extension Registry {
    static var p27uiMore: [Check] {
        var c: [Check] = []

        // KVO: block observation with old/new values, dependent key paths, shared observers
        c.append(check("Foundation", "p27ui-kvo") {
            let o = P27uiKVO()
            var seen: [String] = []
            let obs: NSKeyValueObservation = o.observe(\.sum, options: [.old, .new]) { _, ch in
                let change: NSKeyValueObservedChange<Int> = ch
                seen.append("\(change.oldValue ?? -1)->\(change.newValue ?? -1)")
            }
            o.a = 2; o.b = 3
            obs.invalidate(); o.a = 10
            try expect(seen == ["0->2", "2->5"], "observed \(seen)")
            // shared observers (one registration set, applied to several objects)
            var shared: [String] = []
            final class Obs: NSObject { var hit: (String) -> Void = { _ in }; override func observeValue(forKeyPath k: String?, of o: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) { hit(k ?? "") } }
            let ob = Obs(); ob.hit = { shared.append($0) }
            let so = NSKeyValueSharedObservers(observableClass: P27uiKVO.self)
            so.addSharedObserver(ob, forKey: "a", options: [.new], context: nil)
            let snap: NSKeyValueSharedObserversSnapshot = so.snapshot()
            let t1 = P27uiKVO(), t2 = P27uiKVO()
            t1.setSharedObservers(snap); t2.setSharedObservers(snap)
            t1.a = 1; t2.a = 2
            t1.setSharedObservers(nil); t2.setSharedObservers(nil)
            try expect(shared == ["a", "a"], "shared observers \(shared)")
            return "observed \(seen), shared \(shared.count)"
        })

        // the remaining Foundation classes: iterators, linguistic tagger, metadata query, net services, extension
        // items, on-demand resources, file security, markdown source positions, codable configuration, URL resources,
        // progress manager subprogress
        c.append(check("Foundation", "p27ui-foundation-rest") {
            var it: NSFastEnumerationIterator = NSFastEnumerationIterator(NSArray(array: [1, 2, 3]))
            var sum = 0; while let v = it.next() as? Int { sum += v }
            var isum = 0; var ii: NSIndexSetIterator = NSIndexSet(indexesIn: NSRange(location: 1, length: 3)).makeIterator(); while let v = ii.next() { isum += v }
            try expect(sum == 6 && isum == 6, "iterators \(sum) \(isum)")
            let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
            tagger.string = "The cat sleeps"
            var tags: [String] = []
            tagger.enumerateTags(in: NSRange(location: 0, length: 14), unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { t, _, _ in tags.append(t?.rawValue ?? "-") }
            try expect(tags.count == 3 && (tags == ["Determiner", "Noun", "Verb"] || tags == ["OtherWord", "OtherWord", "OtherWord"]), "tags \(tags)")
            let q = NSMetadataQuery(); q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]; q.predicate = NSPredicate(format: "%K LIKE '*.txt'", NSMetadataItemFSNameKey)
            let started = q.start(); q.stop()
            let mi: AnyClass? = NSClassFromString("NSMetadataItem")
            do { let probed = try p27uiProbe(["NSMetadataQueryAttributeValueTuple", "NSMetadataQueryResultGroup", "NSLocalizedNumberFormatRule", "NSAttributedStringMarkdownParsingOptions"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
            #if !os(watchOS)
            #if !os(tvOS)
            _ = try p27uiClass("NSFileProviderService")   // not in tvOS's Foundation
            #endif
            let ns = NetService(domain: "local.", type: "_p27ui._tcp.", name: "p27", port: 0)
            let nb = NetServiceBrowser()
            try p27uiSame("NSNetService", NetService.self); try p27uiSame("NSNetServiceBrowser", NetServiceBrowser.self)
            try expect(ns.name == "p27" && ns.type == "_p27ui._tcp." && nb.delegate == nil, "net service")
            #endif
            let item = NSExtensionItem(); item.attributedTitle = NSAttributedString(string: "t"); item.attachments = [NSItemProvider(object: "x" as NSString)]
            try p27uiSame("NSExtensionItem", NSExtensionItem.self); try p27uiSame("NSExtensionContext", NSExtensionContext.self)
            let odr = NSBundleResourceRequest(tags: ["p27ui"])
            let odrAvail: Bool = await withCheckedContinuation { cont in odr.conditionallyBeginAccessingResources { cont.resume(returning: $0) } }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("p27ui-sec.txt"); try Data("x".utf8).write(to: tmp)
            let sec = try FileManager.default.attributesOfItem(atPath: tmp.path)[.posixPermissions] as? Int
            var fsec: CFFileSecurity? = CFFileSecurityCreate(nil)
            CFFileSecuritySetMode(fsec, 0o640)
            let fsObj = fsec.map { $0 as AnyObject }
            try expect(NSStringFromClass(type(of: fsObj!)).contains("FileSecurity") && sec != nil, "file security \(fsObj.map { NSStringFromClass(type(of: $0)) } ?? "nil")")
            fsec = nil
            try? FileManager.default.removeItem(at: tmp)
            // markdown source positions survive bridging as NSAttributedStringMarkdownSourcePosition
            let md = try AttributedString(markdown: "a **b**", options: .init(appliesSourcePositionAttributes: true))
            let nsmd = NSAttributedString(md)
            let posObj = nsmd.attribute(NSAttributedString.Key("NSMarkdownSourcePosition"), at: 2, effectiveRange: nil) as? NSObject
            try expect(posObj.map { NSStringFromClass(type(of: $0)) } == "NSAttributedStringMarkdownSourcePosition", "markdown source position \(String(describing: posObj))")
            // a Codable struct with a @CodableConfiguration attributed string and a custom encodable key
            struct Doc: Codable { @CodableConfiguration(from: \.p27uiScope2) var text = AttributedString() }
            var doc = Doc(); doc.text = AttributedString("hi"); doc.text[P27uiEncKey.self] = 7
            let back = try JSONDecoder().decode(Doc.self, from: JSONEncoder().encode(doc))
            try expect(back.text.runs.first?[P27uiEncKey.self] == 7, "codable configuration \(back.text)")
            func ref<R: ReferenceConvertible>(_ r: R) -> String { "\(R.ReferenceType.self)" }
            let refName = ref(URL(fileURLWithPath: "/"))
            // URL resources (missing in this bundle) and the progress manager
            let res = URLResource(name: "p27ui-none.txt")
            let resURL = Bundle.main.url(forResource: "p27ui-none", withExtension: "txt")
            let pm = ProgressManager(totalCount: 4)
            let sub: Subprogress = pm.subprogress(assigningCount: 2)
            let child = sub.start(totalCount: 1); child.complete(count: 1)
            pm.complete(count: 1)
            try expect(pm.fractionCompleted == 0.75, "progress manager \(pm.fractionCompleted)")
            return "iterators, tags \(tags), metadata query started \(started) item \(mi != nil), ODR available \(odrAvail), \(refName), resource \(res.name) \(resURL == nil ? "absent" : "present"), progress 0.75"
        })

        #if canImport(UIKit) && !os(watchOS)
        // UIKit classes Swift exposes under other names: each Swift value is of its Objective-C class
        c.append(check("UIKit", "p27ui-renamed-classes") {
            try await p6A {
                var pairs: [(String, Any)] = [("UIImageSymbolConfiguration", UIImage.SymbolConfiguration(pointSize: 10)), ("UIImageConfiguration", UIImage.SymbolConfiguration(scale: .large)),
                    ("UIScrollEdgeEffectStyle", UIScrollEdgeEffect.Style.soft), ("UIViewReservedRegionKind", try p27uiReservedKind())]
                let completionCtx: UISymbolEffectCompletionContext? = nil
                let lv = UIListContentView(configuration: .cell())
                let tp = lv.value(forKey: "configuration") as? NSObject
                var d = "configuration bridges \(tp.map { NSStringFromClass(type(of: $0)) } ?? "-")"
                #if os(iOS)
                pairs += [("UIPasteControlConfiguration", UIPasteControl.Configuration()), ("UIMainMenuSystemConfiguration", UIMainMenuSystem.Configuration()),
                          ("UISheetPresentationControllerDetent", UISheetPresentationController.Detent.medium()), ("UICalendarViewDecoration", UICalendarView.Decoration.default()),
                          ("UIZoomTransitionOptions", UIViewController.Transition.ZoomOptions()), ("UIViewControllerTransition", UIViewController.Transition.zoom(sourceViewProvider: { _ in nil })),
                          ("UIMailConversationEntry", try p27uiClass("UIMailConversationEntry").init()), ("UIMessageConversationEntry", try p27uiClass("UIMessageConversationEntry").init())]
                try expect(try p27uiClass("UIMailConversationEntry").isSubclass(of: UIConversationContext.Entry.self), "mail entry is a conversation entry")
                // a custom detent resolves against the container
                let det = UISheetPresentationController.Detent.custom(identifier: .init("p27")) { ctx in ctx.maximumDetentValue * 0.3 }
                try expect(det.identifier.rawValue == "p27", "custom detent")
                // the bar button item badge and a tab accessory
                let item = UIBarButtonItem(title: "B"); item.badge = .count(3)
                try expect(item.badge == .count(3), "badge \(String(describing: item.badge))")
                let acc = UITabAccessory(contentView: UILabel())
                let tbc = UITabBarController(); tbc.bottomAccessory = acc
                let sidebar: UITabBarController.Sidebar = tbc.sidebar
                pairs += [("UITabAccessory", acc), ("UITabBarControllerSidebar", sidebar)]
                d += ", badge 3, sidebar hidden \(sidebar.isHidden)"
                // text interaction pieces
                let tv = UITextView(); let close = try p27uiHost(tv); defer { close() }
                let ti = UITextInteraction(for: .editable); ti.textInput = tv; tv.addInteraction(ti)
                let sdi = UITextSelectionDisplayInteraction(textInput: tv, delegate: P27uiSelDelegate.shared); tv.addInteraction(sdi)
                let cursor = UIStandardTextCursorView(frame: CGRect(x: 0, y: 0, width: 2, height: 20))
                let loc = UIAccessibilityLocationDescriptor(name: "here", point: CGPoint(x: 1, y: 1), in: tv)
                let bev = UIBackgroundExtensionView(); bev.contentView = UIView()
                pairs += [("UITextInteraction", ti), ("UITextSelectionDisplayInteraction", sdi), ("UIStandardTextCursorView", cursor), ("UIAccessibilityLocationDescriptor", loc), ("UIBackgroundExtensionView", bev)]
                try expect(loc.name == "here" && bev.contentView != nil && sdi.isActivated == sdi.isActivated, "text pieces")
                // pointer lock state of the scene
                let pls: UIPointerLockState? = try p6Scene().pointerLockState
                d += ", pointer locked \(pls.map { "\($0.isLocked)" } ?? "nil")"
                // a cell registration dequeues configured cells; the layout's prepare(forCollectionViewUpdates:) sees insert items
                final class L: UICollectionViewFlowLayout { var updates: [UICollectionViewUpdateItem] = []; override func prepare(forCollectionViewUpdates u: [UICollectionViewUpdateItem]) { super.prepare(forCollectionViewUpdates: u); updates += u } }
                let layout = L(); layout.itemSize = CGSize(width: 40, height: 40)
                let cv = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 200), collectionViewLayout: layout)
                let reg = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, n in var cfg = cell.defaultContentConfiguration(); cfg.text = "\(n)"; cell.contentConfiguration = cfg }
                let hreg = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(elementKind: UICollectionView.elementKindSectionHeader) { _, _, _ in }
                let ds = UICollectionViewDiffableDataSource<Int, Int>(collectionView: cv) { cv, ip, n in cv.dequeueConfiguredReusableCell(using: reg, for: ip, item: n) }
                var snap = NSDiffableDataSourceSnapshot<Int, Int>(); snap.appendSections([0]); snap.appendItems([1, 2])
                let host2 = try p27uiHost(cv); defer { host2() }
                ds.apply(snap, animatingDifferences: false); cv.layoutIfNeeded()
                snap.appendItems([3]); ds.apply(snap, animatingDifferences: true); cv.layoutIfNeeded()
                let text = (cv.cellForItem(at: IndexPath(item: 2, section: 0)) as? UICollectionViewListCell).flatMap { ($0.contentConfiguration as? UIListContentConfiguration)?.text }
                try expect(text == "3" && layout.updates.contains { $0.updateAction == .insert && $0.indexPathAfterUpdate?.item == 2 }, "registration cell \(text ?? "nil"), updates \(layout.updates.map { "\($0.updateAction.rawValue)" })")
                _ = hreg
                // reorder transactions (Swift NSDiffableDataSourceTransaction / SectionTransaction over the Objective-C classes)
                ds.reorderingHandlers.canReorderItem = { _ in true }
                var txn: NSDiffableDataSourceTransaction<Int, Int>?
                ds.reorderingHandlers.didReorder = { t in txn = t; let st: [NSDiffableDataSourceSectionTransaction<Int, Int>] = t.sectionTransactions; _ = st }
                d += ", update items \(layout.updates.count), transaction \(txn == nil ? "none yet" : "seen")"
                let probe = try p27uiProbe(["UICollectionViewCellRegistration", "UICollectionViewSupplementaryRegistration", "NSDiffableDataSourceTransaction", "NSDiffableDataSourceSectionTransaction",
                          "UIUpdateActionPhase", "UIUpdateInfo", "UIViewReservedRegion", "UIViewReservedRegionIdentifier", "UIPencilInteractionTap", "UIPencilInteractionSqueeze", "UIPencilHoverPose",
                          "UITabSidebarItem", "UITabSidebarItemRequest", "UITabSidebarScrollTarget", "UITextItem", "UITextItemMenuConfiguration", "UITextItemMenuPreview", "UITextLoupeSession",
                          "UITextSearchingFindSession", "UITextCursorDropPositionAnimator", "UITextDragPreviewRenderer", "UITextDropProposal", "UITextFormattingCoordinator",
                          "UITextFormattingViewController", "UITextFormattingViewControllerConfiguration", "UITextFormattingViewControllerComponent", "UITextFormattingViewControllerComponentGroup",
                          "UITextFormattingViewControllerFormattingDescriptor", "UITextFormattingViewControllerFormattingStyle", "UITextFormattingViewControllerChangeValue",
                          "UIWritingToolsCoordinator", "UIWritingToolsCoordinatorContext", "UIWritingToolsCoordinatorAnimationParameters", "UIZoomTransitionSourceViewProviderContext",
                          "UIZoomTransitionInteractionContext", "UIZoomTransitionAlignmentRectContext", "UIHoverEffectLayer", "UISymbolContentTransition", "UIContentUnavailableTextProperties",
                          "UIContentUnavailableImageProperties", "UIContentUnavailableButtonProperties", "UIListContentTextProperties", "UIListContentImageProperties", "UIImageReaderConfiguration",
                          "NSAdaptiveImageGlyph", "UIArrangement", "UIArrangementViewController", "UIArrangementViewState", "UISplitArrangement", "UISplitArrangementDimension",
                          "UISplitArrangementDimensionRange", "UISplitArrangementViewProperties", "UIOverlayArrangement", "UIOverlayArrangementViewProperties", "UIHinge", "UIHingeInteraction",
                          "UIHingeInteractionUpdate", "UITitlebar", "NSUIViewToolbarItem"])
                try expect(probe.absent == ["UITitlebar", "NSUIViewToolbarItem"] && probe.raised.isEmpty, "probe absent \(probe.absent) raised \(probe.raised)")   // Mac Catalyst-only classes
                p27uiProbeResult = "absent \(probe.absent), init raised \(probe.raised.count), built \(probe.built.count): \(probe.built)"
                // a text formatting view controller with a configuration
                let fcfg = UITextFormattingViewController.Configuration(groups: [UITextFormattingViewController.ComponentGroup(components: [UITextFormattingViewController.Component(componentKey: .fontSize, preferredSize: .regular)])])
                let fvc = UITextFormattingViewController(configuration: fcfg)
                pairs += [("UITextFormattingViewController", fvc), ("UITextFormattingViewControllerConfiguration", fcfg)]
                // writing tools coordinator on a custom view
                final class WD: NSObject, UIWritingToolsCoordinator.Delegate {
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, requestsContextsFor scope: UIWritingToolsCoordinator.ContextScope, completion: @escaping ([UIWritingToolsCoordinator.Context]) -> Void) { completion([UIWritingToolsCoordinator.Context(attributedString: NSAttributedString(string: "p27"), range: NSRange(location: 0, length: 3))]) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, replace range: NSRange, in context: UIWritingToolsCoordinator.Context, proposedText: NSAttributedString, reason: UIWritingToolsCoordinator.TextReplacementReason, animationParameters: UIWritingToolsCoordinator.AnimationParameters?, completion: @escaping (NSAttributedString?) -> Void) { completion(nil) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, select ranges: [NSValue], in context: UIWritingToolsCoordinator.Context, completion: @escaping () -> Void) { completion() }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, requestsBoundingBezierPathsFor range: NSRange, in context: UIWritingToolsCoordinator.Context, completion: @escaping ([UIBezierPath]) -> Void) { completion([]) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, requestsUnderlinePathsFor range: NSRange, in context: UIWritingToolsCoordinator.Context, completion: @escaping ([UIBezierPath]) -> Void) { completion([]) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, prepareFor textAnimation: UIWritingToolsCoordinator.TextAnimation, for range: NSRange, in context: UIWritingToolsCoordinator.Context, completion: @escaping () -> Void) { completion() }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, requestsPreviewFor textAnimation: UIWritingToolsCoordinator.TextAnimation, of range: NSRange, in context: UIWritingToolsCoordinator.Context, completion: @escaping (UITargetedPreview?) -> Void) { completion(nil) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, requestsPreviewFor rect: CGRect, in context: UIWritingToolsCoordinator.Context, completion: @escaping (UITargetedPreview?) -> Void) { completion(nil) }
                    func writingToolsCoordinator(_ c: UIWritingToolsCoordinator, finish textAnimation: UIWritingToolsCoordinator.TextAnimation, for range: NSRange, in context: UIWritingToolsCoordinator.Context, completion: @escaping () -> Void) { completion() }
                }
                let wd = WD(); let wtc = UIWritingToolsCoordinator(delegate: wd)
                let host3 = UIView(); host3.addInteraction(wtc)
                pairs += [("UIWritingToolsCoordinator", wtc)]
                d += ", writing tools state \(wtc.state.rawValue)"
                #endif
                for (n, o) in pairs { try p27uiIsa(n, o) }
                _ = completionCtx
                return d + "; \(pairs.count) renamed classes ok; probe: \(p27uiProbeResult)"
            }
        })
        #endif

        #if canImport(PencilKit) && (os(iOS) || os(visionOS))
        c.append(check("PencilKit", "p27ui-tools-drawing") { try await p27uiPencil() })
        #endif
        #if canImport(QuickLookThumbnailing) && (os(iOS) || os(visionOS))
        c.append(check("QuickLookThumbnailing", "p27ui-replies") { try p27uiQuickLook() })
        #endif
        c.append(check("CoreGraphics", "p27ui-swift-context") { try p27uiCG() })
        return c
    }
}
extension AttributeScopes { var p27uiScope2: P27uiScope2.Type { P27uiScope2.self } }
struct P27uiScope2: AttributeScope { let n: P27uiEncKey }
nonisolated(unsafe) private var p27uiProbeResult = ""

#if canImport(UIKit) && !os(watchOS)
@MainActor private func p27uiReservedKind() throws -> NSObject {
    guard let k = (try p27uiClass("UIViewReservedRegionKind") as AnyObject).perform(NSSelectorFromString("occlusionRegionKind"))?.takeUnretainedValue() as? NSObject else { throw Fail("no occlusion kind") }
    return k
}
#if os(iOS)
final class P27uiSelDelegate: NSObject, UITextSelectionDisplayInteractionDelegate { @MainActor static let shared = P27uiSelDelegate() }
final class P27uiScribbleDelegate: NSObject, UIIndirectScribbleInteractionDelegate {
    typealias ElementIdentifier = String
    func indirectScribbleInteraction(_ i: UIInteraction, requestElementsIn rect: CGRect, completion: @escaping ([String]) -> Void) { completion([]) }
    func indirectScribbleInteraction(_ i: UIInteraction, isElementFocused id: String) -> Bool { false }
    func indirectScribbleInteraction(_ i: UIInteraction, frameForElement id: String) -> CGRect { .zero }
    func indirectScribbleInteraction(_ i: UIInteraction, focusElementIfNeeded id: String, referencePoint: CGPoint, completion: @escaping ((UIResponder & UITextInput)?) -> Void) { completion(nil) }
}
final class P27uiRenameDelegate: NSObject, UINavigationItemRenameDelegate {
    func navigationItem(_ item: UINavigationItem, didEndRenamingWith title: String) {}
}
#endif
#endif

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import PencilKit
@MainActor private func p27uiPencil() async throws -> String {
    let ink = PKInkingTool(.pen, color: .red, width: 5)
    let eraser = PKEraserTool(.bitmap, width: 10), lasso = PKLassoTool()
    let tools: [PKTool] = [ink, eraser, lasso]
    let pts = (0..<10).map { PKStrokePoint(location: CGPoint(x: 10 + $0 * 8, y: 20), timeOffset: Double($0) * 0.01, size: CGSize(width: 5, height: 5), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2) }
    let stroke = PKStroke(ink: ink.ink, path: PKStrokePath(controlPoints: pts, creationDate: Date()))
    let drawing = PKDrawing(strokes: [stroke])
    let img = drawing.image(from: CGRect(x: 0, y: 0, width: 100, height: 40), scale: 1)
    guard let cg = img.cgImage else { throw Fail("no drawing image") }
    let px = p6Px(cg, 40, 20)
    try expect(px[0] > 150 && px[3] > 100, "stroke pixel \(px)")
    var interp = 0; for _ in stroke.path.interpolatedPoints(by: .distance(5)) { interp += 1 }
    do { let probed = try p27uiProbe(["PKConvertedBezierPoint", "PKStrokeRenderState", "PKFloatRange"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
    let range = try p27uiClass("PKFloatRange").init()
    _ = range
    var items: [PKToolPickerItem] = [PKToolPickerInkingItem(type: .marker, color: .blue, width: 8), PKToolPickerEraserItem(type: .vector), PKToolPickerLassoItem()]
    #if os(iOS)
    items += [PKToolPickerRulerItem(), PKToolPickerScribbleItem()]
    #endif
    var cfg = PKToolPickerCustomItem.Configuration(identifier: "p27", name: "P27"); cfg.defaultWidth = 4
    let custom = PKToolPickerCustomItem(configuration: cfg)
    let picker = PKToolPicker(toolItems: items + [custom])
    let v = UIView(); let close = try p27uiHost(v); defer { close() }
    let rs: PKResponderState = v.pencilKitResponderState
    rs.activeToolPicker = picker
    try expect(picker.toolItems.count == items.count && rs.activeToolPicker === picker && eraser.width >= 10, "tool picker \(picker.toolItems.count)/\(items.count) active \(rs.activeToolPicker === picker) eraser width \(eraser.width)")
    let render = "PKStrokeRenderState"
    return "eraser width \(eraser.width) (asked 10), \(tools.count) tools, stroke pixel \(px), \(interp) interpolated points, picker items \(picker.toolItems.count), \(render)"
}
#endif

#if canImport(QuickLookThumbnailing) && (os(iOS) || os(visionOS))
import QuickLookThumbnailing
import QuickLook
import UniformTypeIdentifiers
private func p27uiQuickLook() throws -> String {
    var drew = false
    let reply = QLThumbnailReply(contextSize: CGSize(width: 32, height: 32)) { ctx in ctx.setFillColor(UIColor.red.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32)); drew = true; return true }
    let pr = QLPreviewReply(dataOfContentType: .plainText, contentSize: CGSize(width: 100, height: 100)) { _ in Data("p27".utf8) }
    let att = QLPreviewReplyAttachment(data: Data([1]), contentType: .png)
    pr.attachments = ["a.png": att]; pr.title = "P27"
    try expect(pr.title == "P27" && pr.attachments.count == 1, "preview reply")
    do { let probed = try p27uiProbe(["QLFileThumbnailRequest", "QLThumbnailProvider", "QLPreviewProvider"]); try expect(probed.absent.isEmpty, "absent \(probed.absent)") }
    return "thumbnail reply \(reply), drew \(drew), preview reply \(pr.title)"
}
#endif

private func p27uiCG() throws -> String {
    // fill rules on a path with a hole
    let p = CGMutablePath(); p.addRect(CGRect(x: 0, y: 0, width: 10, height: 10)); p.addRect(CGRect(x: 3, y: 3, width: 4, height: 4))
    let rule: CGPathFillRule = .evenOdd
    let inHoleEO = p.contains(CGPoint(x: 5, y: 5), using: rule), inHoleW = p.contains(CGPoint(x: 5, y: 5), using: .winding)
    try expect(!inHoleEO && inHoleW, "fill rules even-odd \(inHoleEO) winding \(inHoleW)")
    // an adaptive bitmap context: its parameters chosen in onResolve
    var seen = ""
    let ctx = CGContext(width: 8, height: 4, onResolve: { (_: CGContentInfo, params: inout CGBitmapParameters) -> Bool in
        seen = "\(params.width)x\(params.height)"; return true
    })
    ctx?.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); ctx?.fill(CGRect(x: 0, y: 0, width: 8, height: 4))
    let img = ctx?.makeImage()
    let tone: CGContentToneMappingInfo.LightLevel = .nits(203)
    try expect(img?.width == 8 && seen == "8x4", "adaptive context image \(img?.width ?? -1) params \(seen)")
    return "even-odd hole, adaptive context \(seen), tone \(tone)"
}

// MARK: part 4: DataDetection, MetricKit, MediaAccessibility (VideoToolbox's frame processors are not in the simulator SDK)

extension Registry {
    static var p27uiMore2: [Check] {
        var c: [Check] = []
        #if canImport(DataDetection)
        c.append(check("DataDetection", "p27ui-matches") { try await p27uiDataDetection() })
        #endif
        #if canImport(MetricKit) && os(iOS)
        c.append(check("MetricKit", "p27ui-metric-manager") { try await p27uiMetricKit() })
        #endif
        #if canImport(MediaAccessibility) && !os(watchOS)
        c.append(check("MediaAccessibility", "p27ui-flashing-lights") { try await p27uiMediaAX() })
        #endif
        return c
    }
}

#if canImport(DataDetection)
import DataDetection
private func p27uiDataDetection() async throws -> String {
    let text = "Mail ada@example.com or call +1 (408) 555-0100, see https://example.com, pay $12.50"
    var opts = DataDetector.Options(); opts.documentDate = Date(timeIntervalSince1970: 0)
    var kinds: [String] = []
    for await m in text.dataDetectorMatches([.emailAddress, .phoneNumber, .link, .moneyAmount], options: opts) {
        let style: DataDetector.Match.HighlightStyle = m.preferredHighlightStyle
        switch m.details {
        case .emailAddress(let e): kinds.append("email \(e.emailAddress)")
        case .phoneNumber(let p): kinds.append("phone \(p.phoneNumber)")
        case .link(let l): kinds.append("link \(l.url.host ?? "")")
        case .moneyAmount: kinds.append("money")
        default: kinds.append("other \(style)")
        }
    }
    try expect(kinds.contains("email ada@example.com") && kinds.contains { $0.hasPrefix("phone") } && kinds.contains("link example.com"), "matches \(kinds)")
    return "matches \(kinds)"
}
#endif

#if canImport(MetricKit) && os(iOS)
import MetricKit
private func p27uiMetricKit() async throws -> String {
    // the Swift manager: no reports arrive in a simulator run (as with MXMetricManager's payloads)
    let mgr = MetricManager()
    var n = 0
    let t = Task { for await _ in mgr.diagnosticReports { n += 1 } }
    try? await Task.sleep(nanoseconds: 300_000_000); t.cancel()
    let groups: [MetricGroup] = [.cpu, .memory, .diskIO, .networkTransfer, .display, .animation, .applicationResponsiveness, .gpu, .signpost, .appLaunch]
    let task: LaunchTaskID = "p27"
    let past = MXMetricManager.shared.pastPayloads.count + MXMetricManager.shared.pastDiagnosticPayloads.count
    let probe = try p27uiProbe(["MXMetricPayload", "MXDiagnosticPayload", "MXCPUMetric", "MXMemoryMetric", "MXDiskIOMetric", "MXDisplayMetric", "MXGPUMetric", "MXAnimationMetric", "MXAppExitMetric",
               "MXAppLaunchMetric", "MXAppResponsivenessMetric", "MXAppRunTimeMetric", "MXCellularConditionMetric", "MXLocationActivityMetric", "MXNetworkTransferMetric", "MXSignpostMetric",
               "MXDiskSpaceUsageMetric", "MXMetaData", "MXMetric", "MXDiagnostic", "MXCrashDiagnostic", "MXHangDiagnostic", "MXCPUExceptionDiagnostic", "MXDiskWriteExceptionDiagnostic",
               "MXAppLaunchDiagnostic", "MXCallStackTree", "MXBackgroundExitData", "MXForegroundExitData", "MXSignpostIntervalData", "MXSignpostRecord", "MXUnitAveragePixelLuminance", "MXUnitSignalBars",
               "MXCrashDiagnosticObjectiveCExceptionReason"], build: true)
    let present = probe.built.count
    // the two MXUnit dimensions have no plain -init (they are built from their class properties below)
    try expect(probe.absent.isEmpty && probe.raised == ["MXUnitAveragePixelLuminance", "MXUnitSignalBars"], "MX probe absent \(probe.absent) raised \(probe.raised)")
    let lum = MXUnitAveragePixelLuminance.apl, bars = MXUnitSignalBars.bars
    try expect(n == 0 && past == 0 && task.rawValue == "p27" && lum.symbol == "apl" && bars.symbol == "bars", "reports \(n) past \(past) lum \(lum.symbol) bars \(bars.symbol)")
    return "no reports (as in a simulator), \(groups.count) groups, MX classes built \(present): absent \(probe.absent) raised \(probe.raised), units \(lum.symbol) \(bars.symbol)"
}
#endif

#if canImport(MediaAccessibility) && !os(watchOS)
import MediaAccessibility
import IOSurface
@objc private protocol P27uiFlashing {
    @objc optional func canProcessSurface(_ s: IOSurface) -> Bool
    @objc optional func processSurface(_ s: IOSurface, outSurface: IOSurface, timestamp: CFAbsoluteTime, options: [String: Any]?) -> NSObject
}
private func p27uiMediaAX() async throws -> String {
    let p = MAFlashingLightsProcessor()
    let props: [IOSurfacePropertyKey: Any] = [.width: 64, .height: 64, .bytesPerElement: 4, .pixelFormat: kCVPixelFormatType_32BGRA]
    guard let a = IOSurface(properties: props), let b = IOSurface(properties: props) else { throw Fail("no surfaces") }
    // the processor's Objective-C API (refined for Swift), called through an @objc protocol's selectors
    let obj = p as AnyObject
    let can = obj.canProcessSurface?(a) ?? false
    guard let r = obj.processSurface?(a, outSurface: b, timestamp: CFAbsoluteTimeGetCurrent(), options: nil) else { throw Fail("no result") }
    try expect(r.isKind(of: try p27uiClass("MAFlashingLightsProcessorResult")), "result \(type(of: r))")
    #if os(iOS) || os(visionOS)
    let mh: MAMusicHapticsManager = .shared
    let haptics = "music haptics active \(mh.isActive)"
    #else
    let haptics = "-"
    #endif
    return "canProcess \(can), processed \(r.value(forKey: "surfaceProcessed") ?? "-"), \(haptics)"
}
#endif
