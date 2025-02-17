# Generated by Django 5.1.4 on 2025-01-25 08:38

from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("core", "0012_make_document_creator_and_invitation_issuer_optional"),
    ]

    operations = [
        migrations.RunSQL(
            "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;",
            reverse_sql="DROP EXTENSION IF EXISTS fuzzystrmatch;",
        ),
    ]
