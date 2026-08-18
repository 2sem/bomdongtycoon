import SpriteKit

/// Maps the emoji glyphs still used as identity/data values (e.g. `CustomerNode.wantedMenu`,
/// `MainStallScene.staffEmoji`) to the generated art asset that renders them on screen.
/// The glyphs themselves stay as-is everywhere they're used for matching/lookup —
/// only the rendering call sites go through this to pick a sprite texture.
enum EmojiArt {

    private static let assetNames: [String: String] = [
        "🥬": "produce_cabbage",
        "🥗": "produce_salad",
        "🥘": "produce_stew",
        "🌱": "crop_sprout",
        "🌿": "crop_growing",
        "🌰": "seed_hint",
        "⚠️": "warning_badge",
        "📦": "warehouse_box",
        "👷": "worker_hint",
        "🍽": "dish_icon",
        "👤": "staff_icon",
        "🌸": "flower_deco",
        "🌺": "flower_deco",
        "🌼": "flower_deco",
        "⛺": "building_tent",
        "🏪": "building_store",
        "🏬": "building_mall",
        "🧑": "person_adult",
        "👩": "person_woman",
        "👨": "person_man",
        "🧓": "person_elder",
        "👴": "person_elder_man",
        "👵": "person_elder_woman",
        "🧒": "person_kid",
        "👧": "person_kid_girl",
        "👦": "person_kid_boy",
        "👱‍♂️": "person_man",
        "👱‍♀️": "person_woman",
        "🧑‍💼": "person_adult",
        "👩‍💼": "person_woman",
        "👨‍💼": "person_man",
        "🧑‍🎤": "person_adult",
        "👩‍🎓": "person_woman",
        "👨‍🎓": "person_man",
        "🧑‍🍳": "staff_chef_man",
        "👨‍🍳": "staff_chef_man",
        "👩‍🍳": "staff_chef_woman",
        "👨‍🌾": "staff_farmer",
        "🧑‍🌾": "staff_farmer_veteran",
    ];

    /// Asset catalog image name for a given emoji glyph, or nil when there's no generated art for it.
    static func imageName(for emoji: String) -> String? {
        assetNames[emoji];
    }

    /// Builds a sized `SKSpriteNode` for the given glyph, falling back to a plain color
    /// square if the glyph has no mapped art (keeps the node visible instead of crashing).
    static func sprite(for emoji: String, size: CGSize) -> SKSpriteNode {
        guard let name = imageName(for: emoji) else {
            return SKSpriteNode(color: .clear, size: size);
        }
        let node = SKSpriteNode(imageNamed: name);
        node.size = size;
        return node;
    }
}
