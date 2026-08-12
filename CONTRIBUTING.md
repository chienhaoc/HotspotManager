# Contributing to HotspotManager 🤝

Thank you for your interest in contributing to **HotspotManager**!

## Guidelines

1. **Keep it Pure & Native**:
   - The core design philosophy of this project is **zero external dependencies**.
   - All code must run on standard Windows 10/11 using built-in PowerShell 5.1 and WinForms/WinRT APIs without requiring extra package managers or runtime installations.

2. **UI & UX**:
   - Maintain dark mode aesthetic and DPI awareness.
   - All UI elements must use dynamic layout management (`TableLayoutPanel`, `Dock`, `Margin`) rather than absolute pixel coordinates.

3. **Submitting Changes**:
   - Fork the repository.
   - Create a feature branch (`git checkout -b feature/my-feature`).
   - Test your changes locally on Windows 10 or 11.
   - Submit a Pull Request with a clear explanation of what was added or fixed.

## Reporting Issues

If you encounter a bug or have a feature suggestion, please open an Issue on GitHub with:
- Windows version (e.g. Windows 11 23H2)
- PowerShell version (`$PSVersionTable.PSVersion`)
- Steps to reproduce or expected behavior
