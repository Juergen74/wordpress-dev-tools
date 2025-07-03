# WordPress Dev Tools (.deb Installer)

A powerful, portable LAMP + WordPress development stack packaged as a `.deb` for Ubuntu systems.

This package sets up everything you need for rapid WordPress development in just minutes.

Designed to work best with a fresh install of Ubuntu.

---

## ✨ Features

* Apache, PHP, MariaDB full LAMP stack
* WordPress-ready project scaffolding
* phpMyAdmin (root/root)
* MailHog for local email capture
* mkcert for HTTPS with local certificates
* Xdebug preconfigured
* Easy domain setup: `mysite.local`, `client.local`, etc.

---

## 📦 Installation

```bash
sudo dpkg -i wordpress-dev-tools.deb
```

Then run:

```bash
/opt/wordpress-tools/create-LAMP.sh
```

*(Do NOT run create-LAMP.sh with `sudo`, it needs to run as your user to configure permissions properly.)*

---

## 🚀 Services Available

* 🧱 Apache default site → [http://localhost](http://localhost)
* 🧪 PHP info           → [http://localhost/info.php](http://localhost/info.php)
* 🛠 phpMyAdmin         → [http://localhost/phpmyadmin](http://localhost/phpmyadmin) (`root` / `root`)
* 📬 MailHog            → [http://localhost:8025](http://localhost:8025)

---

## 🧰 Create Your First Project

```bash
/opt/wordpress-tools/add_project.sh
```

You’ll be prompted for a local domain (e.g. `myproject.local`).

---

## 📂 Tools Provided

```
/opt/wordpress-tools/create-LAMP.sh       # Main LAMP + dev tools installer
/opt/wordpress-tools/add_project.sh       # Create a new WordPress site
/opt/wordpress-tools/remove_project.sh    # Delete a WordPress site
/opt/wordpress-tools/list_projects.sh     # List all configured projects
/opt/wordpress-tools/setup-gui-tools.sh   # (optional) Install GUI tools (Brave, Chrome, Firefox, VS Code, gnome-sushi) with dev bookmarks
```

If desired, you can run the helper to install additional GUI tools and browsers:

```bash
/opt/wordpress-tools/setup-gui-tools.sh
```

This interactive helper lets you optionally install browsers and developer tools, and automatically sets up bookmarks for local development sites in Brave and Chrome.

---

## 📄 Disclaimer

This package is provided as-is for **local development only**. It performs system-level changes (e.g. web server config, database setup).

> ⚠️ Use it only on development machines. You accept all responsibility for its use.

See `DISCLAIMER.txt` for full details.

---

## 📜 License

MIT License — see `LICENSE` file.

---

🎉 Happy coding & enjoy your WordPress dev environment!
