# Exercise 15: Yves Storefront - Supplier Page

In this exercise, you will build a Yves (storefront) interface to display suppliers. You will create a controller with two actions: one to list all suppliers in a table, and another to show details of a single supplier.

You will learn how to:
- Create a Yves Controller with multiple actions
- Register routes using the RouteProviderPlugin
- Create Twig templates for the storefront
- Wire dependencies through the Yves DependencyProvider and Factory
- Access the SearchClient from the Yves layer
- Handle request parameters and redirects

## Prerequisites

- Completed Exercise 11 (Search) — suppliers must be indexed in Elasticsearch
- Understanding of the Client layer and DependencyProvider pattern

## Loading the Exercise

```bash
./exercises/load.sh supplier intermediate/yves-storefront/skeleton
docker/sdk cli composer dump-autoload
docker/sdk console cache:empty-all
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
- Yves uses `AbstractController` from `Spryker\Yves\Kernel`
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

### Part 3: Routes

Routes connect URLs to controller actions.

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/Plugin/Router/SupplierPageRouteProviderPlugin.php`:

1. Add two constants:
   - `ROUTE_NAME_SUPPLIER_INDEX = 'supplier-index'`
   - `ROUTE_NAME_SUPPLIER_DETAIL = 'supplier-detail'`

2. In `addRoutes()`, call both private methods to add routes to the collection

3. Implement `addSupplierIndexRoute()`:
   - Use `$this->buildRoute('/supplier', 'SupplierPage', 'Index', 'indexAction')`
   - Set method to GET: `$route->setMethods(['GET'])`
   - Add to collection with the index route name constant

4. Implement `addSupplierDetailRoute()`:
   - Use `$this->buildRoute('/supplier/detail', 'SupplierPage', 'Index', 'detailAction')`
   - Set method to GET
   - Add to collection with the detail route name constant

> **buildRoute()** parameters: path, module, controller, action

---

### Part 4: Controller

The Controller handles HTTP requests and returns data for templates.

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/Controller/IndexController.php`:

#### 4.1 indexAction - List All Suppliers

```php
public function indexAction(Request $request): array
{
    // 1. Get the client from factory
    $supplierCollection = $this->getFactory()
        ->getSupplierSearchClient()
        ->searchSuppliers([]); // Pass empty array for no filters

    // 2. Return array for template
    return [
        'suppliers' => $supplierCollection->getSuppliers(),
    ];
}
```

> **searchSuppliers([]):** The empty array means no search filters — returns all suppliers.

#### 4.2 detailAction - Single Supplier

```php
public function detailAction(Request $request)
{
    // 1. Get ID from query parameter
    $idSupplier = $request->query->getInt('id');

    // 2. Validate ID exists
    if (!$idSupplier) {
        $this->addErrorMessage('Supplier ID is required.');
        return $this->redirectResponse('/supplier');
    }

    // 3. Fetch supplier
    $supplier = $this->getFactory()
        ->getSupplierSearchClient()
        ->findSupplierById($idSupplier);

    // 4. Handle not found
    if (!$supplier) {
        $this->addErrorMessage('Supplier not found.');
        return $this->redirectResponse('/supplier');
    }

    // 5. Return for template
    return [
        'supplier' => $supplier,
    ];
}
```

> **Request parameters:** Use `$request->query->getInt('id')` for URL query params (e.g., `/supplier/detail?id=1`)
> 
> **Flash messages:** `addErrorMessage()` shows a toast notification that persists through redirects
> 
> **Redirect:** `redirectResponse()` returns a Response object for redirects

---

### Part 5: Templates

Twig templates render the HTML using data from controllers.

#### 5.1 List Template (index.twig)

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/Theme/default/templates/index/index.twig`:

```twig
{% extends template('page-layout-main') %}

{% block title %}{{ 'Suppliers' | trans }}{% endblock %}

{% block content %}
    <div class="container">
        <h1>{{ 'Suppliers' | trans }}</h1>
        
        {% if suppliers is empty %}
            <div class="alert alert-info">{{ 'No suppliers found.' | trans }}</div>
        {% else %}
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>{{ 'ID' | trans }}</th>
                        <th>{{ 'Name' | trans }}</th>
                        <th>{{ 'Email' | trans }}</th>
                        <th>{{ 'Phone' | trans }}</th>
                        <th>{{ 'Status' | trans }}</th>
                        <th>{{ 'Actions' | trans }}</th>
                    </tr>
                </thead>
                <tbody>
                    {% for supplier in suppliers %}
                        <tr>
                            <td>{{ supplier.idSupplier }}</td>
                            <td>{{ supplier.name }}</td>
                            <td>{{ supplier.email }}</td>
                            <td>{{ supplier.phone }}</td>
                            <td>
                                {% if supplier.status == 1 %}
                                    <span class="badge badge-success">{{ 'Active' | trans }}</span>
                                {% else %}
                                    <span class="badge badge-secondary">{{ 'Inactive' | trans }}</span>
                                {% endif %}
                            </td>
                            <td>
                                <a href="{{ url('supplier-detail', {id: supplier.idSupplier}) }}" class="btn btn-sm btn-primary">
                                    {{ 'View' | trans }}
                                </a>
                            </td>
                        </tr>
                    {% endfor %}
                </tbody>
            </table>
        {% endif %}
    </div>
{% endblock %}
```

> **template('page-layout-main'):** The base layout for Yves storefront pages
> 
> **url():** Generates URLs using route names: `{{ url('supplier-detail', {id: 1}) }}` → `/supplier/detail?id=1`
> 
> **supplier.idSupplier:** Access transfer properties using camelCase (idSupplier, not id_supplier)

#### 5.2 Detail Template (detail.twig)

**Coding time:**

Open `src/SprykerAcademy/Yves/SupplierPage/Theme/default/templates/index/detail.twig`:

```twig
{% extends template('page-layout-main') %}

{% block title %}{{ supplier.name }}{% endblock %}

{% block content %}
    <div class="container">
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="{{ url('supplier-index') }}">{{ 'Suppliers' | trans }}</a></li>
                <li class="breadcrumb-item active" aria-current="page">{{ supplier.name }}</li>
            </ol>
        </nav>

        <h1>{{ supplier.name }}</h1>
        
        <div class="card">
            <div class="card-body">
                <table class="table table-borderless">
                    <tbody>
                        <tr><th>ID</th><td>{{ supplier.idSupplier }}</td></tr>
                        <tr><th>Name</th><td>{{ supplier.name }}</td></tr>
                        <tr><th>Description</th><td>{{ supplier.description }}</td></tr>
                        <tr><th>Email</th><td>{{ supplier.email }}</td></tr>
                        <tr><th>Phone</th><td>{{ supplier.phone }}</td></tr>
                        <tr>
                            <th>Status</th>
                            <td>
                                {% if supplier.status == 1 %}
                                    <span class="badge badge-success">{{ 'Active' | trans }}</span>
                                {% else %}
                                    <span class="badge badge-secondary">{{ 'Inactive' | trans }}</span>
                                {% endif %}
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
            <div class="card-footer">
                <a href="{{ url('supplier-index') }}" class="btn btn-secondary">
                    {{ 'Back to List' | trans }}
                </a>
            </div>
        </div>
    </div>
{% endblock %}
```

---

## Testing the Storefront

After implementing all parts:

1. Clear cache:
   ```bash
   docker/sdk console cache:empty-all
   ```

2. Visit the list page:
   ```
   http://yves.eu.spryker.local/supplier
   ```

3. Click "View" on a supplier to see the detail page:
   ```
   http://yves.eu.spryker.local/supplier/detail?id=1
   ```

---

## Key Concepts Summary

### Yves vs Zed

| Aspect | Zed (Back Office) | Yves (Storefront) |
|--------|-------------------|-------------------|
| Controller base | `AbstractController` (Kernel) | `AbstractController` (Kernel) |
| Template layout | `@Gui/Layout/layout.twig` | `page-layout-main` |
| Routing | `navigation.xml` | `RouteProviderPlugin` |
| URL generation | Hardcoded paths | `url()` Twig function |
| CSS framework | Spryker Gui | Bootstrap (default theme) |

### Controller Return Types

| Return | Purpose |
|--------|---------|
| `array` | Renders Twig template with data |
| `Response` | Raw response (e.g., redirect, JSON) |

### Request Handling

```php
// Query parameters: /supplier/detail?id=1
$id = $request->query->getInt('id');

// Flash messages
$this->addErrorMessage('Error message');
$this->addSuccessMessage('Success message');

// Redirect
return $this->redirectResponse('/supplier');
```

---

## Solution

```bash
./exercises/load.sh supplier intermediate/yves-storefront/complete
```
