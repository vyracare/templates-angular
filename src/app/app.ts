import { Component, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { VcHeadingComponent, VcTextComponent } from '@vyracare/design-system';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, VcHeadingComponent, VcTextComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  protected readonly title = signal('[name-generic]');
}
