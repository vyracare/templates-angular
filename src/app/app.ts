import { Component, signal, ChangeDetectionStrategy } from '@angular/core';
import { VcHeadingComponent, VcTextComponent } from '@vyracare/design-system';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [VcHeadingComponent, VcTextComponent],
  templateUrl: './app.html',
  changeDetection: ChangeDetectionStrategy.Eager,
  styleUrl: './app.scss'
})
export class App {
  protected readonly title = signal('[name-generic]');
}
