import AppKit

enum TokenRole { case keyword, builtin, number, string, comment }

struct LanguageDef {
    let id: String
    let name: String
    let extensions: [String]
    var keywords: Set<String> = []
    var builtins: Set<String> = []
    var lineCommentPrefixes: [String] = []       // "//", "#" ...
    var blockComments: [(open: String, close: String)] = []  // ("/*","*/")
    var stringDelims: [Character] = ["\"", "'"]  // quote chars
    var customPatterns: [(pattern: String, role: TokenRole)] = []

    static func kw(_ s: String) -> Set<String> { Set(s.split(separator: " ").map(String.init)) }
}

extension Set where Element == String {
    /// Compact keyword-list literal: `.kw("if for while ...")`.
    static func kw(_ s: String) -> Set<String> { Set(s.split(separator: " ").map(String.init)) }
}

enum Languages {
    static let all: [LanguageDef] = core + web

    /// Language-menu structure: Core / Web submenus.
    static var groups: [(name: String, languages: [LanguageDef])] { [("Core", core), ("Web", web)] }

    static var plain: LanguageDef {
        .init(id: "plain", name: "Plain text", extensions: ["txt", "log"])
    }

    static func byID(_ id: String) -> LanguageDef? { all.first { $0.id == id } ?? (id == "plain" ? plain : nil) }

    static func forPath(_ path: String) -> LanguageDef {
        let ext = (path as NSString).pathExtension.lowercased()
        return all.first { $0.extensions.contains(ext) } ?? plain
    }

    // MARK: core languages (menu order =  1–6)

    static var clike: LanguageDef {
        var l = LanguageDef(id: "c", name: "C / C++ / C# / Java", extensions: ["c","cc","cpp","cxx","h","hh","hpp","cs","java","m","mm"])
        l.keywords = .kw("auto break case catch class const continue default do else enum extern for goto if inline new public private protected return sizeof static struct switch template this throw try typedef union unsigned virtual void volatile while import package")
        l.builtins = .kw("int float double char bool long short signed size_t uint8_t uint16_t uint32_t int64_t string vector map set array list null true false nullptr nil")
        l.lineCommentPrefixes = ["//"]
        l.blockComments = [("/*", "*/")]
        return l
    }

    static var javascript: LanguageDef {
        var l = LanguageDef(id: "js", name: "JavaScript / TypeScript", extensions: ["js","jsx","ts","tsx"])
        l.keywords = .kw("var let const function if else for while do switch case break continue return typeof instanceof in of new delete void yield async await class extends super this static import export default from try catch finally throw as interface type enum implements")
        l.builtins = .kw("number string boolean object symbol bigint null undefined true false console Math JSON Promise Array Object String Number Boolean Map Set Date RegExp Error require module exports")
        l.lineCommentPrefixes = ["//"]
        l.blockComments = [("/*", "*/")]
        l.stringDelims = ["\"", "'", "`"]
        return l
    }

    static var python: LanguageDef {
        var l = LanguageDef(id: "python", name: "Python", extensions: ["py","pyw"])
        l.keywords = .kw("def class if elif else for while break continue pass lambda import from as with global nonlocal assert del raise not and or in is try except finally yield async await match case")
        l.builtins = .kw("None True False int float str list dict set tuple bool bytes complex range len print open type super isinstance input id hash repr sorted enumerate zip map filter any all min max abs round sum next iter")
        l.lineCommentPrefixes = ["#"]
        l.stringDelims = ["\"", "'"]
        return l
    }

    static var php: LanguageDef {
        var l = LanguageDef(id: "php", name: "PHP", extensions: ["php"])
        l.keywords = .kw("function if else elseif for foreach while do switch case break continue return echo print new class extends implements interface trait public private protected static const var as namespace use require include global unset isset empty eval try catch finally throw fn match")
        l.builtins = .kw("int float string bool object mixed void null true false array stdClass Exception Closure echo_count count strlen strpos substr trim explode implode json_encode json_decode preg_match file fread fwrite fopen fclose")
        l.lineCommentPrefixes = ["//", "#"]
        l.blockComments = [("/*", "*/")]
        return l
    }

    static var golang: LanguageDef {
        var l = LanguageDef(id: "go", name: "Go", extensions: ["go"])
        l.keywords = .kw("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var")
        l.builtins = .kw("bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 string uint uintptr rune append cap close copy delete len make new panic print println recover")
        l.lineCommentPrefixes = ["//"]
        l.blockComments = [("/*", "*/")]
        l.stringDelims = ["\"", "`"]   // ` raw strings too
        return l
    }

    static var rust: LanguageDef {
        var l = LanguageDef(id: "rust", name: "Rust", extensions: ["rs"])
        l.keywords = .kw("as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while")
        l.builtins = .kw("bool char f32 f64 i8 i16 i32 i64 isize str u8 u16 u32 u64 usize Box Vec Option Result String println print panic format vec")
        l.lineCommentPrefixes = ["//"]
        l.blockComments = [("/*", "*/")]
        return l
    }

    static var core: [LanguageDef] { [plain, clike, javascript, python, php, golang, rust] }
}
