from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('formular', '0069_demoscenario_single_default'),
    ]

    operations = [
        migrations.AlterField(
            model_name='demoscenario',
            name='is_default',
            field=models.BooleanField(
                default=False,
                help_text=(
                    'Этот сценарий автоматически запускается при открытии демонстрации. '
                    'При выборе другого сценария текущий выбор будет снят.'
                ),
                verbose_name='Запускать демонстрацию по умолчанию',
            ),
        ),
    ]
