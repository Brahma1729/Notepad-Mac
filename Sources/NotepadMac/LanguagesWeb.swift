import AppKit

extension Languages {
    static var json: LanguageDef {
        var l = LanguageDef(id: "json", name: "JSON", extensions: ["json"])
        l.keywords = .kw("true false null")
        return l
    }

    static var sql: LanguageDef {
        var l = LanguageDef(id: "sql", name: "SQL", extensions: ["sql"])
        l.keywords = .kw("SELECT FROM WHERE INSERT INTO VALUES UPDATE DELETE SET CREATE TABLE ALTER DROP INDEX VIEW JOIN LEFT RIGHT INNER OUTER ON AS AND OR NOT NULL PRIMARY KEY FOREIGN REFERENCES DEFAULT UNIQUE CHECK CONSTRAINT BEGIN COMMIT ROLLBACK CASE WHEN THEN ELSE END GROUP BY HAVING ORDER LIMIT OFFSET UNION ALL DISTINCT COUNT SUM AVG MIN MAX EXISTS BETWEEN LIKE IN IS")
        l.lineCommentPrefixes = ["--", "#"]
        l.blockComments = [("/*", "*/")]
        return l
    }

    static var html: LanguageDef {
        var l = LanguageDef(id: "html", name: "HTML / XML", extensions: ["html","htm","xml","xhtml","svg"])
        l.keywords = .kw("a abbr address article b body br button code dd div dl dt em form h1 h2 h3 h4 h5 h6 head header hr html i img input li main nav ol option p pre script section select span strong style table td textarea th title tr ul video")
        l.blockComments = [("<!--", "-->")]
        return l
    }

    static var css: LanguageDef {
        var l = LanguageDef(id: "css", name: "CSS / SCSS", extensions: ["css","scss"])
        l.keywords = .kw("color background border margin padding font size width height display flex grid position top left right bottom z-index opacity transform transition animation content")
        l.blockComments = [("/*", "*/")]
        return l
    }

    static var shell: LanguageDef {
        var l = LanguageDef(id: "shell", name: "Shell / Bash", extensions: ["sh","bash","zsh"])
        l.keywords = .kw("if then else elif fi for do done while until case esac function in return exit local export source alias set unset shift readonly echo cd ls grep awk sed cat head tail curl")
        l.lineCommentPrefixes = ["#"]
        return l
    }

    static var ruby: LanguageDef {
        var l = LanguageDef(id: "ruby", name: "Ruby", extensions: ["rb"])
        l.keywords = .kw("def end class module if elsif else unless while until for do begin rescue ensure return yield self super new include require raise lambda proc case when then")
        l.builtins = .kw("Integer Float String Symbol Array Hash TrueClass FalseClass NilClass Regexp Range Object Proc Exception puts print gets scanf")
        l.lineCommentPrefixes = ["#"]
        return l
    }

    static var yaml: LanguageDef {
        var l = LanguageDef(id: "yaml", name: "YAML / TOML / INI", extensions: ["yml","yaml","toml","ini","cfg","conf","env"])
        l.lineCommentPrefixes = ["#", ";"]
        return l
    }

    static var markdown: LanguageDef {
        var l = LanguageDef(id: "md", name: "Markdown", extensions: ["md","markdown","rst"], stringDelims: [])
        l.customPatterns = [
            ("^ {0,3}#{1,6}[^\n]*", .keyword),
            ("\\*\\*[^*\\n]+?\\*\\*", .builtin),
            ("`[^`\\n]+`", .comment),
            ("^[>][^\n]*", .comment)
        ]
        return l
    }

    static var web: [LanguageDef] { [json, sql, html, css, shell, ruby, yaml, markdown] }
}
