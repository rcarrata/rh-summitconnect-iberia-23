import * as gesso from "./gesso/gesso.js";

const html = `
<body>
  <header>
    <div>
      <div>
        <span class="material-icons-outlined">emoji_people</span>
        Summit Connect Iberia Demo!
      </div>
    </div>
  </header>
  <section>
    <div>
      <div>Mi nombre es <b id="name"></b>.</div>

      <form id="hello-form" style="margin-bottom: 2em;">
        <div class="form-field">
          <button type="submit">Hola Red Hat Summit Connect!</button>
        </div>
      </form>

      <div id="hello-table"></div>
    </div>
  </section>
  <footer>
  </footer>
</body>
`;

function renderRequest(value, item, context) {
  const elem = gesso.createElement(null, "div");

  elem.innerHTML = item.request.text.replace(item.request.name, `<b>${item.request.name}</b>`);

  return elem;
}

function renderResponse(value, item, context) {
  const elem = gesso.createElement(null, "div");

  elem.innerHTML = item.response.text.replace(item.response.name, `<b>${item.response.name}</b>`);

  return elem;
}

const helloTable = new gesso.Table("hello-table", [
  ["Frontend requests", "request", renderRequest],
  ["Backend responses", "response", renderResponse],
]);

class MainPage extends gesso.Page {
  constructor(router) {
    super(router, "/", html);

    this.body.$("#hello-form").addEventListener("submit", event => {
      event.preventDefault();

      gesso.postJson("/api/hello", {
        text: `Hola! Yo soy ${this.name}.`,
        name: this.name,
      });
    });
  }

  process() {
    if (!this.id) {
      gesso.postJson("/api/generate-id", null, data => {
        this.id = data.id;
        this.name = data.name;

        super.process();
      });

      return;
    }

    super.process();
  }

  updateContent() {
    $("#name").textContent = this.name;

    gesso.getJson("/api/data", data => {
      const responses = Object.values(data).reverse();

      helloTable.update(responses, data);
    });
  }
}

const router = new gesso.Router();

new MainPage(router);

new EventSource("/api/notifications").onmessage = event => {
  router.page.updateContent();
};
