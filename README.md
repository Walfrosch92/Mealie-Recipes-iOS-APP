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
- Multi-language support (English & German).

### Recipes
- Browse all recipes from your Mealie server.
- View and check off ingredients and preparation steps.
- Add ingredients (individually or all) to the shopping list.
- **Built-in Timer**: Start, modify, or cancel timers with audible alerts.
- **Ingredient Scaling**: Instantly view 0.5x, 1x, 2x, or 3x ingredient quantities.

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

![IMG_0658](https://github.com/user-attachments/assets/7bc8224f-9fab-4c9d-a52b-a2fd5d7d6553)  
![IMG_0659](https://github.com/user-attachments/assets/24b6a472-652b-437f-b0eb-c8739ef2a031)  
![IMG_0660](https://github.com/user-attachments/assets/a9d93e50-10e5-48e1-b271-3fe8b4b7a8b4)  
![IMG_0661](https://github.com/user-attachments/assets/b67e8870-1c5d-43ff-978e-f1eca8bd422a)  
![IMG_0662](https://github.com/user-attachments/assets/afea89fe-fb49-4481-9cbe-29cb359bd633)  
![IMG_0663](https://github.com/user-attachments/assets/a31ba44f-0a72-4220-bf7a-ee23273d8dee)  
![IMG_0666](https://github.com/user-attachments/assets/a9ed0310-97fc-4afd-9b93-5b0ccc03dc45)  
![IMG_0665](https://github.com/user-attachments/assets/bf286227-91f5-4ad5-b192-c1ef213260f0)  
![IMG_0664](https://github.com/user-attachments/assets/529ef002-8cea-4ce9-abdb-8c76524b9895)

---

## Contributing

This project is open to the community! If you’re interested in testing, improving features, or contributing code, feel free to open an issue or pull request.  
Whether you're a Swift developer or just love Mealie – your feedback and support are welcome!

---

## Roadmap

- [ ] Offline mode  
- [x] Caching for recipes and shopping list  
- [x] **Recipe upload support** (Text, Image & URL – powered by OpenAI)  
- [x] Multi-language support (German & English)

---

## Requirements

- iOS 17+  
- A running Mealie server (tested with API v2.8.0)

---

## License

MIT – see [LICENSE](LICENSE) file for details.
