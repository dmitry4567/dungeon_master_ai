import Foundation

func runScript(_ source: String) {
    var error: NSDictionary?
    if let script = NSAppleScript(source: source) {
        script.executeAndReturnError(&error)
        if let error = error {
            print("Ошибка AppleScript: \(error)")
        }
    }
}

let script = """
tell application "System Events"
    tell process "ControlCenter"
        
        -- Открыть Пункт управления
        click menu bar item 1 of menu bar 1
        delay 0.5
        
        -- Нажать «Видеоэффекты»
        click button "Видеоэффекты" of window 1
        delay 0.5
        
        -- Переключить «В центре внимания»
        tell checkbox "В центре внимания" of window 1
            click
        end tell
        
        delay 0.3
        
        -- Закрыть Пункт управления (нажать вне окна)
        key code 53
        
    end tell
end tell
"""

runScript(script)