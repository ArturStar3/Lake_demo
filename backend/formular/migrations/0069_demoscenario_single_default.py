from django.db import migrations, models
from django.db.models import Q


def retain_latest_default_scenario(apps, schema_editor):
    DemoScenario = apps.get_model('formular', 'DemoScenario')
    defaults = DemoScenario.objects.filter(is_default=True).order_by('-updated_at', '-created_at', 'pk')
    chosen = defaults.first()
    if chosen:
        defaults.exclude(pk=chosen.pk).update(is_default=False)


class Migration(migrations.Migration):

    dependencies = [
        ('formular', '0068_rename_formular_de_scenari_stage_ord_idx_formular_de_scenari_0ee30f_idx_and_more'),
    ]

    operations = [
        migrations.RunPython(retain_latest_default_scenario, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name='demoscenario',
            constraint=models.UniqueConstraint(
                fields=('is_default',),
                condition=Q(('is_default', True)),
                name='formular_one_default_demo_scenario',
            ),
        ),
    ]
