from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from accounts.enums import ModuleLevel, UserStatus
from accounts.models import SecurityGroup
from formular.models import Country


User = get_user_model()


class Command(BaseCommand):
    help = 'Создать или обновить ограниченную учётную запись для демонстрационного контейнера'

    def handle(self, *args, **options):
        if not settings.DEMO_AUTO_LOGIN_ENABLED:
            self.stdout.write('Автоматический вход для демонстрации отключён.')
            return

        username = settings.DEMO_AUTO_LOGIN_USERNAME.strip()
        password = settings.DEMO_AUTO_LOGIN_PASSWORD
        if not username or not password:
            raise CommandError(
                'DEMO_AUTO_LOGIN_USERNAME and DEMO_AUTO_LOGIN_PASSWORD must be set when DEMO_AUTO_LOGIN_ENABLED=True.'
            )

        with transaction.atomic():
            group, _ = SecurityGroup.objects.update_or_create(
                name='Демонстрация (только просмотр)',
                defaults={
                    'description': 'Автоматический вход в отдельном демонстрационном контейнере',
                    **{field: ModuleLevel.READ for field in (
                        'targets', 'events', 'operational_situations', 'formular',
                        'country_dossier', 'persons', 'equipment', 'reports',
                        'data_exchange', 'demo_scenarios',
                    )},
                    'can_manage_reference': False,
                    'can_manage_users': False,
                    'can_approve_registrations': False,
                },
            )
            group.countries.set(Country.objects.all())

            user = User.objects.filter(username__iexact=username).first()
            created = user is None
            if created:
                user = User(username=username)
            elif user.is_superuser or user.is_staff:
                raise CommandError(
                    'DEMO_AUTO_LOGIN_USERNAME must not point to an administrator account.'
                )
            user.is_active = True
            user.is_staff = False
            user.is_superuser = False
            user.set_password(password)
            user.save()

            profile = user.profile
            profile.status = UserStatus.ACTIVE
            profile.must_change_password = False
            profile.full_name = 'Демонстрационный просмотр'
            profile.approved_at = timezone.now()
            profile.save(update_fields=['status', 'must_change_password', 'full_name', 'approved_at'])
            profile.security_groups.set([group])

        action = 'Создана' if created else 'Обновлена'
        self.stdout.write(self.style.SUCCESS(f'{action} демонстрационная учётная запись «{username}».'))
