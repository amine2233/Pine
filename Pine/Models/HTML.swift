//
//  HTML.swift
//  Pine
//
//  Created by Luka Kerr on 26/4/18.
//  Copyright © 2018 Luka Kerr. All rights reserved.
//

import Cocoa
import Foundation

class HTML {

  static let shared = HTML()

  // Currently WKWebView doesn't allow local resources to be loaded (css, js)
  // via file:/// so we have to read from the file and insert it into the html inline
  // This file IO only happens when the singleton is instantiated, but the WKWebView
  // has to re-parse the entire HTML returned from getHTML()
  private init() {
    self.loadCSS()
    self.loadJS()
    self.loadPluginScripts()
  }

  var baseCSS: String = ""
  var css: String = ""
  var js: String = ""
  var y: Int = 0

  var pluginScripts: [String] = []

  // The innerHTML contents are passed in here rather than stored
  // to prevent asynchronous race conditions changing the content on startup
  public func getHTML(with contents: String, direction: NSWritingDirection? = .natural) -> String {
    // If using system appearance, let window background control the color used
    let bodyBackground = preferences[.useSystemAppearance] ? "transparent" : theme.background.hex

    // Direction of text, by default is auto
    let dir = direction == .rightToLeft ? "rtl" : "auto"

    return(
      """
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          \(css)
          \(baseCSS)
          html, body { background: \(bodyBackground); }
          code { background: \(theme.code.hex) !important }
          p, h1, h2, h3, h4, h5, h6, ul, ol, dl, li, table, tr { color: \(theme.text.hex); }
          table tr { background: \(theme.background.hex); }
          table tr:nth-child(2n) { background: \(theme.background.darker.hex); }
          table tr th, table tr td { border-color: \(theme.code.hex) }
        </style>
        <script>\(js)</script>
        <script>hljs.initHighlightingOnLoad();</script>

        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.10.0-rc/katex.min.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.10.0-rc/katex.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/KaTeX/0.10.0-rc/contrib/auto-render.min.js"></script>
        <script src=\(mermaidScript())></script>
      </head>
      <body dir="\(dir)">
        \(contents)

        <div>
          <script>
            window.scrollTo(0, \(y));
          </script>
          <script>
            renderMathInElement(document.body, {delimiters: [
              {left: "$$", right: "$$", display: true},
              {left: "$", right: "$", display: false},
            ]});
          </script>
          \(loadMermaid())
          \(pluginScripts.joined(separator: " "))
        </div>
      </body>
      </html>
      """
    )
  }

  public func updateSyntaxTheme() {
    self.loadCSS()
  }

  // MARK: - Private functions for setting up the HTML contents

  fileprivate func loadJS() {
    guard
      let jsFile = Bundle.main.path(forResource: "highlight-js/highlight", ofType: "js"),
      let jsResult = try? String(contentsOf: URL(fileURLWithPath: jsFile), encoding: .utf8)
    else { return }

    js = jsResult
  }

  fileprivate func loadCSS() {
    guard
      let cssFile = Bundle.main.path(forResource: "Markdown", ofType: "css"),
      let cssThemeFile = Bundle.main.path(forResource: "/highlight-js/styles/\(theme.syntax)", ofType: "css"),
      let cssContents = try? String(contentsOf: URL(fileURLWithPath: cssFile), encoding: .utf8),
      let cssThemeContents = try? String(contentsOf: URL(fileURLWithPath: cssThemeFile), encoding: .utf8)
    else { return }

    css = cssThemeContents
    baseCSS = cssContents
  }

  fileprivate func loadPluginScripts() {
    guard let applicationSupportDirectory = Utils.getApplicationSupportDirectory(for: .plugins) else { return }

    let contents = try? FileManager.default.contentsOfDirectory(
      at: applicationSupportDirectory,
      includingPropertiesForKeys: nil,
      options: []
    )

    let scriptNames = contents?
      .filter { $0.pathExtension == "js" }
      .compactMap { $0.absoluteString.decoded } ?? []

    self.pluginScripts = scriptNames.map { "<script src='\($0)'></script>" }
  }

    private func mermaidScript(version: String = "9.0.0") -> String {
        "\"https://cdnjs.cloudflare.com/ajax/libs/mermaid/\(version)/mermaid.min.js\""
    }

    // HELPME: https://css-tricks.com/making-mermaid-diagrams-in-markdown/
    private func loadMermaid() -> String {
        """
          <script>
          var config = {
              startOnLoad: true,
              theme: (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) ? "dark" : "default",
              flowchart:{
                      useMaxWidth: false,
                      htmlLabels: true
                  }
          };
          mermaid.initialize(config);
          // select <pre class="mermaid"> _and_ <pre><code class="language-mermaid">
          document.querySelectorAll("pre.mermaid, pre>code.language-mermaid").forEach($el => {
            // if the second selector got a hit, reference the parent <pre>
            if ($el.tagName === "CODE")
              $el = $el.parentElement
            // put the Mermaid contents in the expected <div class="mermaid">
            // plus keep the original contents in a nice <details>
            $el.outerHTML = `
              <div class="mermaid">${$el.textContent}</div>
            `
          })
          </script>
        """
    }

}

let html = HTML.shared
