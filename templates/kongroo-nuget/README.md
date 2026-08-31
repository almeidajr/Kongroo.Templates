# ![Kongroo](https://raw.githubusercontent.com/almeidajr/Kongroo.SampleLib/main/assets/icon-32.png) Kongroo.SampleLib

<one-line description of the library>

## Packages

| Package             | Source                  |
| ------------------- | ----------------------- |
| `Kongroo.SampleLib` | `src/Kongroo.SampleLib` |

Each package documents itself in its own `README.md`, which is what nuget.org shows.

## Adding another package

```bash
dotnet new kongroo-lib --packable -n Kongroo.SampleLib.Extras -o src/Kongroo.SampleLib.Extras
dotnet sln add src/Kongroo.SampleLib.Extras/Kongroo.SampleLib.Extras.csproj
```

One `v*` tag packs and publishes every packable project at the same version.
