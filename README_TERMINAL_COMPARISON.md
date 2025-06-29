# Terminal Compatibility & Feature Comparison

## 🎯 Primary Terminal: Warp

Claude Command Runner was designed specifically for **Warp Terminal** to leverage its unique features. While we support other terminals, you'll get the best experience with Warp.

## 📊 Feature Comparison by Terminal

| Feature | Warp | Terminal.app | iTerm2 | Alacritty | Description |
|---------|------|--------------|---------|-----------|-------------|
| **Send Commands** | ✅ | ✅ | ✅ | ✅ | Basic command sending to terminal |
| **Auto Output Capture** | ✅ | ❌ | ❌ | ❌ | Automatically retrieve command results |
| **Exit Code Tracking** | ✅ | ❌ | ❌ | ❌ | Know if commands succeeded or failed |
| **Command Duration** | ✅ | ❌ | ❌ | ❌ | Track how long commands take |
| **History Integration** | ✅ | ❌ | ❌ | ❌ | Access and learn from past commands |
| **Database Access** | ✅ | ❌ | ❌ | ❌ | Direct access to terminal's SQLite database |
| **Smart Suggestions** | ✅ Full | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited | AI-powered command suggestions |
| **Analytics** | ✅ | ❌ | ❌ | ❌ | Command usage statistics and patterns |
| **Auto-Retrieve Mode** | ✅ | ❌ | ❌ | ❌ | Get output without manual intervention |

### Legend:
- ✅ **Full Support** - Feature works completely
- ⚠️ **Limited Support** - Basic functionality only
- ❌ **Not Supported** - Feature unavailable

## 🚀 What This Means For You

### If You Use **Warp Terminal**:
```yaml
Full Workflow Example:
1. You: "Build my iOS app"
2. Claude: Executes 'xcodebuild...'
3. System: Automatically captures output
4. Claude: "Build successful! 0 warnings, 0 errors. Build time: 45s"
```

**You Get:**
- Complete automation
- No manual copy/paste
- Full command history analysis
- Smart, context-aware suggestions
- Detailed analytics

### If You Use **Other Terminals**:
```yaml
Limited Workflow Example:
1. You: "Build my iOS app"
2. Claude: Sends 'xcodebuild...' to Terminal.app
3. You: Must manually check terminal for results
4. Claude: "Command sent to Terminal.app"
```

**You Get:**
- Command sending only
- Manual output checking required
- No automatic result capture
- Basic command suggestions
- No analytics

## 💡 Recommendations

### For Power Users & Developers:
**Use Warp Terminal** - You'll get the full suite of features including:
- Automatic output capture
- Command analytics
- Smart suggestions based on your history
- Complete workflow automation

### For Casual Users:
**Any supported terminal works** - If you just need to send occasional commands:
- Terminal.app, iTerm2, or Alacritty are fine
- You'll miss advanced features but basic functionality works

### For Best Experience:
1. **Install Warp Terminal** (free): https://www.warp.dev/
2. Set Warp as your preferred terminal in config
3. Enjoy full Claude Command Runner capabilities

## 🔧 Configuring Your Preferred Terminal

Edit `~/.claude-command-runner/config.json`:

```json
{
  "terminal": {
    "preferred": "Warp",  // Options: "Warp", "Terminal.app", "iTerm2", "Alacritty"
    "fallbackOrder": ["Warp", "iTerm2", "Terminal.app", "Alacritty"]
  }
}
```

## ❓ FAQ

**Q: Why doesn't output capture work with Terminal.app/iTerm2?**
A: These terminals don't provide programmatic access to command outputs. Warp's SQLite database makes this possible.

**Q: Can I use multiple terminals?**
A: Yes! Configure your preferred terminal and fallback options. Commands will be sent to the first available terminal.

**Q: Will other terminals get full support in the future?**
A: Unlikely for output capture, as it requires terminal-side support. We may add workarounds for specific features.

**Q: Is Warp Terminal free?**
A: Yes, Warp has a free tier that includes all features needed for Claude Command Runner.