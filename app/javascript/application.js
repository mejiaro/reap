// Entry point for the build script in your package.json
import "@hotwired/turbo-rails";
import "phlex_ui";
import "./controllers";
import "./src/jquery";

import { Application } from "@hotwired/stimulus";

const application = Application.start();
