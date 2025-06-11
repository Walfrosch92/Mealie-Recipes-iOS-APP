# Mealie-Recipes-iOS-APP

A native SwiftUI app for iOS and iPadOS that connects to your self-hosted Mealie server.  
Browse recipes, manage your shopping list, upload new recipes – now with image and URL import powered by OpenAI – all fully integrated via the Mealie API.  
**Now available on the [App Store](https://apps.apple.com/us/app/mealie-recipes/id6745433997)!**

---

## Mealie iOS App (Community Project)

A native iOS app built with SwiftUI to connect to your self-hosted [Mealie](https://github.com/mealie-recipes/mealie) server via the official API.  
Designed for iPhone and iPad, this app brings recipe management, shopping lists, and smart uploads to your fingertips.  
If you like this project, consider [supporting the developer on Buy Me a Coffee](https://buymeacoffee.com/walfrosch92).

---

## Features

### Setup
- Configure your Mealie server URL, API token, and optional custom headers.
- Quick access to recipes, shopping list, archived lists, and settings.
- Multi-language support (English, German, Spain, French & Dutch).

### Recipes
- Browse all recipes from your Mealie server.
- View and check off ingredients and preparation steps.
- Add ingredients (individually or all) to the shopping list.
- **Built-in Timer**: Start, modify, or cancel timers with audible alerts. + Timer is focused all the time 
- **Ingredient Scaling**: Instantly view 0.5x, 1x, 2x, or 3x ingredient quantities.
- Edit your Recipe & Update the Recipe Image
- Delete Recipes

### Recipe Upload
- Upload new recipes to Mealie via Image or URL.

### Shopping List
- Fully synced with Mealie’s shopping list API.
- Check items to mark them as completed on the server.
- Manually add items – with smart focus retention for fast entry.
- When completing a shopping trip, checked items are removed from Mealie and archived locally.

### Archive
- Stores completed shopping lists locally.
- Review or delete past lists anytime.

---

## Screenshots

![0x0ss](https://github.com/user-attachments/assets/fe5a428a-31e6-4576-91de-38c4ff53ba08)
![0x0ss-2](https://github.com/user-attachments/assets/c312dfb4-4e0c-4fc1-b4c9-e78f5d20793b)
![0x0ss-3](https://github.com/user-attachments/assets/7337c6dd-f2b0-42d2-9283-36ad18c74132)
![0x0ss-4](https://github.com/user-attachments/assets/9a7f0ec0-5ecf-40fe-b43e-52b7a64d7778)
![0x0ss-5](https://github.com/user-attachments/assets/50be5596-ed02-412d-a2de-720944b111c8)
![0x0ss-6](https://github.com/user-attachments/assets/4fb04a63-9568-4241-b4ad-0718b4392987)


---

## Contributing

This project is open to the community! If you’re interested in testing, improving features, or contributing code, feel free to open an issue or pull request.  
Whether you're a Swift developer or just love Mealie – your feedback and support are welcome!

---

## Roadmap

- [ ] Android App
- [x] Caching for recipes and shopping list  
- [x] **Recipe upload support** (Image & URL – powered by OpenAI)  
- [x] Multi-language support (German, English, Spain, French & Dutch)
- [x] Edit Recipes
- [x] Sync Labels & Categories
- [x] Sync Mealplanner

---

## Requirements

- iOS 17+  
- A running Mealie server (tested with API v2.8.0)

---

## License

MIT – see [LICENSE](LICENSE) file for details.
