# Exercise 18: Yves Storefront - Supplier Page

In this exercise, you will build a Yves (storefront) interface to display suppliers. You will create a controller with two actions: one to list all suppliers in a table, and another to show details of a single supplier.

You will learn how to:
- Wire dependencies through the Yves DependencyProvider and Factory
- Access the SupplierSearchClient from the Yves layer
- Read how a Yves Controller with multiple actions renders Twig templates
- Read how routes are registered with a RouteProviderPlugin
- Handle route and request parameters

## Prerequisites

- Completed Exercise 11 (Search) — suppliers must be indexed in Elasticsearch
- Understanding of the Client layer and DependencyProvider pattern

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/yves-storefront/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console cache:empty-all
docker/sdk console propel:model:build
```

---

## Background: Yves Architecture

Yves is Spryker's storefront layer. It handles HTTP requests from customers and renders the frontend using Twig templates.

```
HTTP Request
    ↓
Router (RouteProviderPlugin)
    ↓
Controller::Action
    ↓
Factory → Client → Elasticsearch/Redis
    ↓
Twig Template
    ↓
HTML Response
```

**Key differences from Zed (Back Office):**
- Yves controllers extend `SprykerShop\Yves\ShopApplication\Controller\AbstractController` and return a `View`
- Templates extend `page-layout-main` instead of `@Gui/Layout/layout.twig`
- Routes are registered via `RouteProviderPlugin` (not navigation.xml)
- URL generation uses `url()` Twig function (not hardcoded paths)

---

## Working on the Exercise

### Part 1: Dependency Provider

The DependencyProvider wires the SupplierSearchClient into the Yves module.

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/SupplierPageDependencyProvider.php`:

1. Add a constant `CLIENT_SUPPLIER_SEARCH` for the dependency key
2. Implement `addSupplierSearchClient()`:
   - Use `$container->set()` with the constant as the key
   - Return `$container->getLocator()->supplierSearch()->client()`
3. Call `addSupplierSearchClient()` in `provideDependencies()`

> **Locator pattern:** `$container->getLocator()->supplierSearch()->client()` resolves the client from the Client layer.

---

### Part 2: Factory

The Factory provides access to the wired dependencies.

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/SupplierPageFactory.php`:

1. Implement `getSupplierSearchClient()`:
   - Use `getProvidedDependency()` with the constant from DependencyProvider
   - Return type: `SupplierSearchClientInterface`

> **Yves Factory vs Zed Factory:** In Yves, the factory extends `AbstractFactory` (not `AbstractCommunicationFactory`).

---

### Part 3: Routes (provided)

Routes connect URLs to controller actions. The skeleton provides them; **review** `src/SprykerAcademy/Yves/SupplierPage/Plugin/Router/SupplierPageRouteProviderPlugin.php`:

| Route name | Path | Action |
|------------|------|--------|
| `supplier-list` | `/suppliers` | `IndexController::listAction()` |
| `supplier-detail` | `/suppliers/{idSupplier}` | `IndexController::detailAction()` |

- `buildRoute()` parameters: path, module, controller, action
- `setMethods(['GET'])` limits the route to GET requests
- `setRequirement('idSupplier', '\d+')` only matches numeric IDs

**Router registration:** `src/SprykerAcademy/Yves/Router/RouterDependencyProvider.php` extends the project's `Pyz\Yves\Router\RouterDependencyProvider` and appends the `SupplierPageRouteProviderPlugin` to `getRouteProvider()`. Because `SprykerAcademy` comes before `Pyz` in the project namespaces, the kernel resolves this class instead of the Pyz one, so no project file has to be edited.

---

### Part 4: Controller (provided)

**Review** `src/SprykerAcademy/Yves/SupplierPage/Controller/IndexController.php`:

#### 4.1 listAction - List All Suppliers

```php
public function listAction(Request $request): View
{
    $supplierCollection = $this->getFactory()
        ->getSupplierSearchClient()
        ->searchSuppliers($request->query->all());

    return $this->view(
        ['suppliers' => $supplierCollection->getSuppliers()],
        [],
        '@SupplierPage/views/list/list.twig',
    );
}
```

> **searchSuppliers():** the query parameters are passed through, so `?q=...` style filters can be added later. With no parameters, all suppliers are returned.

#### 4.2 detailAction - Single Supplier

```php
public function detailAction(Request $request): View
{
    $idSupplier = (int)$request->get('idSupplier');

    $supplier = $this->getFactory()
        ->getSupplierSearchClient()
        ->findSupplierById($idSupplier);

    return $this->view(
        ['supplier' => $supplier],
        [],
        '@SupplierPage/views/detail/detail.twig',
    );
}
```

> **Route parameters:** `{idSupplier}` from the route is available through `$request->get('idSupplier')`.
>
> **view():** the third argument names the template explicitly. Without it, Spryker derives the template from the module, controller and action names.

---

### Part 5: Templates (provided)

Twig templates render the HTML using data from the controller. **Review** them:

- `src/SprykerAcademy/Yves/SupplierPage/Theme/default/views/list/list.twig` — extends `page-layout-main`, reads `_view.suppliers` into `data.suppliers` and renders a table with a link to the detail page: `{{ url('supplier-detail', {idSupplier: supplier.idSupplier}) }}`
- `src/SprykerAcademy/Yves/SupplierPage/Theme/default/views/detail/detail.twig` — shows one supplier and links back to the list

> **url():** generates URLs from route names, so changing a path in the route provider never breaks the links.

---

## Testing the Storefront

After implementing all parts:

1. Clear cache:
   ```bash
   docker/sdk console cache:empty-all
   docker/sdk console propel:model:build
   ```

2. Visit the list page:
   ```
   http://yves.eu.spryker.local/suppliers
   ```

3. Click "View" on a supplier to see the detail page:
   ```
   http://yves.eu.spryker.local/suppliers/1
   ```
   (use an ID from the list; the suppliers were imported in Exercise 8)

---

## Key Concepts Summary

### Yves vs Zed

| Aspect | Zed (Back Office) | Yves (Storefront) |
|--------|-------------------|-------------------|
| Controller base | `Spryker\Zed\Kernel\...\AbstractController` | `SprykerShop\Yves\ShopApplication\Controller\AbstractController` |
| Template layout | `@Gui/Layout/layout.twig` | `page-layout-main` |
| Routing | `navigation.xml` | `RouteProviderPlugin` |
| URL generation | Hardcoded paths | `url()` Twig function |
| CSS framework | Spryker Gui | Bootstrap (default theme) |

### Controller Return Types

| Return | Purpose |
|--------|---------|
| `View` (from `$this->view()`) | Renders a Twig template with data |
| `Response` | Raw response (e.g., redirect, JSON) |

### Request Handling

```php
// Route parameters: /suppliers/{idSupplier}
$idSupplier = (int)$request->get('idSupplier');

// Query parameters: /suppliers?q=acme
$query = $request->query->get('q');

// Flash messages
$this->addErrorMessage('Error message');
$this->addSuccessMessage('Success message');

// Redirect by route name
return $this->redirectResponseInternal('supplier-list');
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/yves-storefront/complete
```
